#/bin/bash
#

page_source=`curl -s ${1}`
episodes=${page_source#*tab-content-episodes}
episodes=${episodes%grid-blocks*}
episodes=`grep href <<< "$episodes"`
for i in ${episodes}; do
        episode=${i#href=\"}
        episode=${episode%\"*}
        if [[ $episode != *\/episode\/* ]]; then continue; fi
        ./download.sh ${episode}
done
exit 0
