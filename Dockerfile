FROM node:18
LABEL maintainer "William Hilton <wmhilton@gmail.com>"
WORKDIR /srv
COPY . .
RUN npm install
EXPOSE 9999
ENV PORT=9999
CMD [ "npm", "start" ]

