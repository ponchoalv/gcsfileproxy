FROM node:16-alpine

WORKDIR /app

COPY index.js ./
COPY package.json ./

RUN npm install

CMD ["node", "index.js"]
