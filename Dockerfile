FROM node:18

RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates && \
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'

WORKDIR /app

COPY entrypoint.sh .
COPY package*.json ./

RUN chmod +x entrypoint.sh && npm install

COPY . .

ENTRYPOINT ["./entrypoint.sh"]
