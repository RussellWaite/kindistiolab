# this file holds all of the images we downloaded with pull_images.sh
export INDEX_FILE="image_list.txt"

# pull_images.sh shoudl have loaded them into the host Docker, we now need to load these into Kind
input=$INDEX_FILE
while IFS= read -r line
do
  kind load docker-image $line
done < "$input"