# Pluto.jl Authentication Server
Some web services, such as GitHub, work best with public-facing web endpoints which manage API authentication. This server is that endpoint for Pluto.

## Deployment
Build the docker image
```
docker build -t pluto-auth:latest .
```
And start it as you would any other container. Note that the port exposed from the Docker container is `3000`

**IMPORTANT**: Configuration for the server inside the docker container is pulled from `.env_prod` rather than `.env`

For example, to start interactively in a temporary container, use the following command:
```
docker run -it --rm -p 80:3000 pluto-auth
```
This will expose pluto-auth on your local machine on port 80.

## Installation
First, make a copy of `.env_template` and name it `.env`. Set the necessary configuration values in `.env`.

Make sure you have node and npm installed, and run `npm install` to install all the necessary dependencies for the project.

The project itself can be run normally with
```
npm start
```
But if you are performing development on the server, run it with the following command:
```
npm run dev
```
This will listen for file changes and restart the server when changes are made to the source code.

## Future Extension
As of now the only authentication supported is for GitHub gist read/write. More will likely come in the future as needed, and endpoints should adhere (when possible) to the following route rules

Say you want to add authentication for Google Drive storage. Two endpoints need to be created
```
/gdrive - The endpoint the user will be redirected to by Pluto, which is responsible for redirecting to Google's authentication URL
/callback/gdrive - The callback endpoint where the Google Drive authentication will redirect back to once the user has authenticated Pluto
```

## TODO
* Switch session adapter from lowdb (file-based json db) to redis or other external state server