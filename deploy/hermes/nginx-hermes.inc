# OpenAI-compatible Hermes test agent. Strip /hermes prefix.
location /hermes/ {
    proxy_pass http://hermes:8642/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Authorization $http_authorization;
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    proxy_set_header Connection '';
    chunked_transfer_encoding on;
}

location = /hermes {
    return 301 /hermes/;
}
