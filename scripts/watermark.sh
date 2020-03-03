#!/bin/bash
#project_dir=`dirname "$(readlink "$0")"`
scripts_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
project_dir="$( dirname "$scripts_dir")";
echo $project_dir
watermark="$project_dir/themes/westar/static/images/westar-watermark.png"

for img in "$project_dir"/content/blog/**/images/*.{jpg,jpeg,png}
do 
     echo "process image $img";
     composite -gravity SouthEast $watermark $img $img
done
