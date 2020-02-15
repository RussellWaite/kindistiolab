# in the worker node, use containerd's unsupported ctr command to get each image installed on the node
export INDEX_FILE="image_list.txt"
docker exec -it kind-worker ctr -n k8s.io images ls | awk 'NR>1 {print $1}' | grep -v 'sha256' | tr -s '[:space:]' > $INDEX_FILE
# above does: 
#   get image info for all images on node
#   remove any that are not named or are sha versions of named ones (i.e. start with sha256:... or are name@sha256:...) 
#   just get the image name, not the whole line 
#   remove excessive whitespace

# pull each image on the node onto the host PC - for later sidelooading into Kind to ease netwrok traffic on constant rebuild 
input=$INDEX_FILE
while IFS= read -r line
do
  docker pull $line 
done < "$input"