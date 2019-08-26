#! /usr/bin/zsh

# in the worker node, use containerd's unsupported ctr command to get each image installed on the node
export INDEX_FILE="image_list.txt"
docker exec -it kind-worker ctr -n k8s.io images ls | awk 'NR>1 {print $1}' | tr -s '[:space:]' > $INDEX_FILE

# pull each image on the node onto the host PC - for later sidelooading into Kind to ease netwrok traffic on constant rebuild 
input=$INDEX_FILE
while IFS= read -r line
do
  docker pull $line 
done < "$input"