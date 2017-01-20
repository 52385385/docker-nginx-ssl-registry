# Configuration of private Docker Registry with Nginx SSL proxied
## Prepare for openssl keys
### Modify openssl.cnf
Make a copy of openssl.cnf which is commonly located in /etc/pki/tls/ and add content to [ v3_ca ] sector and change content in [ca_default] sector
```script
[ req_distinguished_name ]
# ...
# set xxx_default value can make things convenient
commonName_default		= docker.registry # same as one of subjectAltName(SAN) fields
# ...
[ v3_ca ]
# ...
# Subject Alternative Name(s) aka SAN(s), can contain multiple DNS names and IPs to issue
subjectAltName = DNS:docker.registry, IP:192.168.0.202, IP:120.76.115.230, IP:192.168.0.12
#...
```

### Generate ssl keys and certs
A script like following
```shell
# generate rsa key
openssl genrsa -des3 -out ca.key 1024
# copy rsa key without password
openssl rsa -in ca.key -out ca_nopass.key
# generate cert request
openssl req -new -key ca.key -out ca.csr -config ./openssl.cnf
# self-sign cert with 365 days validation
openssl x509 -req -days 365 -in ca.csr -signkey ca.key -extfile ./openssl.cnf -extensions v3_ca -out ca.crt
```

## Basic auth with Nginx
Install httpd-tools if htpasswd command was not found.
```shell
htpasswd -c /root/nginx/conf.d/registry.password testuser testpassword
```

## Configuration file in conf.d
Servers' configurations can be put in folder conf.d and docker nginx no longer need to modify default nginx.conf
### server_443.conf
```script
server {
    listen 443;
    ssl on;
    ssl_certificate /etc/nginx/ssl/ca.crt;
    ssl_certificate_key /etc/nginx/ssl/ca_nopass.key; # make sure nginx will not ask password
    client_max_body_size 0; # disable any limits to avoid HTTP 413 for large image uploads
    chunked_transfer_encoding on; # required to avoid HTTP 411: see [Issue #1486] (https://github.com/docker/docker/issues/1486)

    location /v2/ {
        # Do not allow connections from docker 1.5 and earlier
        # docker pre-1.6.0 did not properly set the user agent on ping, catch "Go *" user agents
        if ($http_user_agent ~ "^(docker\/1\.(3|4|5(?!\.[0-9]-dev))|Go ).*\$" ) {
            return 404;
        }
        auth_basic "registry password";
        auth_basic_user_file /etc/nginx/conf.d/registry.password;
        add_header 'Docker-Distribution-Api-Version' 'registry/2.0' always;
        proxy_pass                          http://REGISTRY_SERVER:5000; # REGISTRY_SERVER is linked alias to registry
        proxy_set_header  Host              $http_host;   # required for docker client's sake
        proxy_set_header  X-Real-IP         $remote_addr; # pass on real client's IP
        proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header  X-Forwarded-Proto $scheme;
        proxy_read_timeout                  900;
    }

    # other locations on this server port
}
```

## Run with docker
docker-compose.yml
```yaml
nginx:
  image: "nginx:latest"
  ports:
    - 80:80
    - 443:443
  links:
    - registry:REGISTRY_SERVER
  volumes:
    - /root/nginx/conf.d:/etc/nginx/conf.d
    - /root/nginx/ssl:/etc/nginx/ssl
    - /root/nginx/html:/usr/share/nginx/html

registry:
  image: "registry:2"
  volumes:
    - /root/nginx/registry:/var/lib/registry
```

## Client Side
```shell
echo yes | cp /root/nginx/ssl/ca.crt /etc/docker/certs.d/IP-or-DNS-of-RegistryServer/
docker login --username xxx --password xxx IP-or-DNS-of-RegistryServer
```

## Reference
1. [Docker学习笔记](https://peihsinsu.gitbooks.io/docker-note-book/content/nginx-registry-proxy.html)
2. [How to create a multi-domain self-signed certificate for Apache2?](http://serverfault.com/questions/73689/how-to-create-a-multi-domain-self-signed-certificate-for-apache2)
3. [Procedure 13.8. Using IP Addresses in Certificate Subject Names](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Deployment_Guide/sssd-ldap-domain-ip.html)
4. [Using SSL with an IP address instead of DNS](https://bowerstudios.com/node/1007)
