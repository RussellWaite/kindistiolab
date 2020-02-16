# kind istio lab
Just a way to repeatedly setup my lab for learning more about istio. Updated FEB 2020 to use kind 0.8.0-alpha & istio 1.4.4

tip - run script with:

. ./setup.sh 

(note for beginners - the first dot is shorthand for source).

This will then set the env variables into your current session - including the generated password for openfaas (FEB 2020 - did not test openfaas, its probably out of date and broken). 

There are a lot of Environment variables at the top of the script to config what gets installed.

## pull_images.sh
This file will exec onto the worker and use containerd's ctr command to view all the images installed. 

It takes just the image name and outputs each one to a new line in the INDEX_FILE.

Finally it will use that INDEX_FILE to pull each image into the host machine's docker image cache. So there are 2 downloads - in the future downloading the image into an archive should be achievable.

## kind_load_images.sh
This script will use the INDEX_FILE to iterate through each image listed and attempt to take it from the host Docker's image cache and side load it into Kind using the kind load command.

The setup scripts calls this. It's used to save nework traffic (as my broadband is not great)

# notes
Helm3 doesn't require Tiller anymore so I've given it another go - the Helm section is currently untested though.

Pull images no longer tries to get the SHA256 images.

Next up will be a CD system, my list of things to try include:
- Jenkins-x
- Spinnaker
- Screwdriver
- maybe Tekton - see super new though.