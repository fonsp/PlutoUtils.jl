FROM node:14

WORKDIR /usr/src/app

COPY . .
COPY ./.env_prod ./.env

RUN npm install

EXPOSE 3000
CMD [ "npm", "start" ]