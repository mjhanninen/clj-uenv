FROM node:14.4
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY out ./out
ENV HOST=0.0.0.0 PORT=8000
EXPOSE 8000
CMD ["node", "out/main.js"]