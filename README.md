# Demo: CICD Integrations with Grype

[![Grype Demo](https://github.com/pvnovarese/grype-demo/actions/workflows/grype-demo.yaml/badge.svg)](https://github.com/pvnovarese/grype-demo/actions/workflows/grype-demo.yaml)

This is a very rough set of demos for integrating Grype with various CICD tools.  If you don't know what Syft is, read up here: https://github.com/anchore/grype

## Scenario 1: GitHub Workflow

Honestly, this is a redundant demo, as there is a pre-canned Action available for your GitHub Workflows: https://github.com/anchore/scan-action - however, this exercise may be useful in understanding what's going on behind the scenes or as a roadmap to integrating with other tools.

Pretty straightforward, just take a look at the .gitlab/workflows/grype-demo.yaml and edit as needed.  The workflow as-is will build an alpine-based image, generate a json vulnerability report, archive the report, and push the image to ghcr.io.

There are some commented-out portions that you can use as a roadmap to doing additional stuff, such as breaking the pipeline before the push if the image contains vulnerabilities above a certain threshold.

## Senario 2: Jenkins Pipeline

This is a more complex demo.  You'll need access to a Jenkins instance and a container registry (the Jenkinsfile assumes you have a Docker Hub account, but can be easily modified to use any other registry).  If you don't have access to a working Jenkins installation, step 1 below will walk you through setting up a disposable Jenkins instance for this exercise.  

### Part 1: Jenkins Setup

We're going to run jenkins in a container to make this fairly self-contained and easily disposable.  This command will run jenkins and bind to the host's docker sock (if you don't know what that means, don't worry about it, it's not important).

`$ docker run -u root -d --name jenkins --rm -p 8080:8080 -p 50000:50000 -v /var/run/docker.sock:/var/run/docker.sock -v /tmp/jenkins-data:/var/jenkins_home jenkinsci/blueocean`

you won't necessarily need to install jq in the jenkins container for this demo, but if you may want it later as you do more with the json report, or if you plan on adding syft into your pipeline:

`$ docker exec --user=root jenkins apk add jq`

Once Jenkins is up and running, we have just a few things to configure:
- Get the initial password (`$ docker logs jenkins`)
- log in on port 8080
- Unlock Jenkins using the password from the logs
- Select “Install Selected Plugins” and create an admin user
- Create a credential so we can push images into Docker Hub:
	- go to manage jenkins -> manage credentials
	- click “global” and “add credentials”
	- Use your Docker Hub username and password (get an access token from Docker Hub if you are using multifactor authentication), and set the ID of the credential to “Docker Hub”.

### Part 2: Check for CVEs with Grype

- Fork this repo
- From the jenkins main page, select “New Item” 
- Name it “grype-demo”
- Choose “pipeline” and click “OK”
- On the configuration page, scroll down to “Pipeline”
- For “Definition,” select “Pipeline script from SCM”
- For “SCM,” select “git”
- For “Repository URL,” paste in the URL of your forked github repo
	e.g. https://github.com/pvnovarese/grype-demo (with your github username)
- Click “Save”
- You’ll now be at the top-level project page.  Click “Build Now”

Jenkins will check out the repo and build an image using the provided Dockerfile.  This image will be a simple copy of an older alpine base image with minor additions.  Once the image is built, Jenkins will call Grype, generate an json-format vulnerability report, then archive the report as a build artifact and push the image to docker hub (or wherever you have configured it). 

Optionally, we can also parse through the output to search for vulnerabilities above a given threshold, and break the pipeline before the image is pushed if any are found.

If you are implementing the threshold gating and would like to see a successful build, go to the github repo, edit the Dockerfile, and change the base image to alpine:latest or busybox:latest (both of which normally have very few if any vulnerabilities as they are meticulously updated), then go back to the Jenkins project page and click “Build now” again. This time, once the image passes our Grype check, Jenkins will push it to Docker Hub using the credentials you provided.

### Part 3: Package Stoplist with Syft (optional)

There is a companion repo and demo for Anchore Syft here: https://github.com/pvnovarese/jenkins-syft-demo

Challenge: can you make a single Jenkinsfile that will pass an image through both syft and grype?

### Part 4: Cleanup
- Kill the jenkins container (it will automatically be removed since we specified --rm when we created it):
	`pvn@gyarados /home/pvn> docker kill jenkins`
- Remove the jenkins-data directory from /tmp
	`pvn@gyarados /home/pvn> sudo rm -rf /tmp/jenkins-data/`
- Remove all demo images from your local machine:
	`pvn@gyarados /home/pvn> docker image ls | grep -E "grype-demo|syft-demo" | awk '{print $3}' | xargs docker image rm -f`

