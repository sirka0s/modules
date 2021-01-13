#!/bin/bash

cat > index.html <<EOF
<h1>Hello World! New Version is here!</h1>
EOF

nohup busybox httpd -f -p ${server_port} &