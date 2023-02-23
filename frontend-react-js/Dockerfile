FROM node:16.18

# set the port for the app
ENV PORT=3000

# copy everything in my computer to this directory in the container
COPY . /frontend-react-js

# set the working directory to this
WORKDIR /frontend-react-js

# install npm 
RUN npm install

EXPOSE ${PORT}

# start the frontend 
CMD ["npm", "start"]