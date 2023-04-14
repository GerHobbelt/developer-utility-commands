cd `dirname $0`
DESCRIBE=`git describe | sed s/-.*//g`
echo $(echo $DESCRIBE | sed 's/\(^.*\.\)\(.*\)/\1/g')$(echo `echo $DESCRIBE | sed s/".*\."//g`+1 | bc)
