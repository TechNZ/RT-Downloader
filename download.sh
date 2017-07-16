#!/bin/bash

## USER VARIABLES
rt_session_id="blah"
max_download_segments="4"
convert="no"
## set this to "on" to piss off your family / flatmates
pissoff_mode="off"

## ENCODER PRESETS AVAILABLE PRESETS DYNAMIC VARIABLES
# ultrafast,superfast, veryfast, faster, fast, medium, slow, slower, veryslow, placebo
script_pid=$BASHPID
enc_preset="veryfast"
enc_container="mp4"
enc_video="libx265"
enc_audio="libvo_aacenc"
enc_threads=12
enc_extras="-x265-params log-level=error"

site=${1#*//}
site=${site%%.*}
short_name=`basename ${1}`
page_source=`curl -s ${1}`

## PREP DIRECTORIES

mkdir -p output/${site}
mkdir -p data/downloading

## tmp directory cleanup
for i in `ls tmp`; do
	if [ -e /proc/${i} ]
	then
		:
	else
		rm -r tmp/${i}
	fi
done

##sponsor check
sponsor=`grep sponsor-gate-overlay <<< "$page_source"`
test -n "${sponsor}" && echo "${site}/${short_name} is a sponsor video, consider upgrading your account" && exit 0

##completion check
egrep -xq "${site}/${short_name}" data/completed.downloads 2>&1 && echo "you already have ${short_name} from ${site}" && exit 0


##downloading check
if [ -e data/downloading/${site}.${short_name} ]
then

	#check if active or stale
	if [ -e /proc/`cat data/downloading/${site}.${short_name}` ]
	then
		echo "${site}/${short_name} is already processing"
		cat "data/downloading/${site}.${short_name}"
		exit 0
	else
		rm "data/downloading/${site}.${short_name}"
		echo "${site}/${short_name} is no longer processing, retrying"
	fi
	
fi

## create tempoary directories if we have made it this far
mkdir -p tmp/${script_pid}/chunks

echo "starting process for ${site}/${short_name}"
input_source=`grep m3u8 <<< "$page_source"`
cdn_source_unfiltered=${input_source#*//}
cdn_source=${cdn_source_unfiltered/index.m3u8*}
long_name=`grep "og:title" <<< "$page_source"`
long_name=${long_name%\"*}
long_name=${long_name##*\"}
long_name=${long_name//\:/\ \-}
long_name=${long_name//\,/\ \-}

## GET QUALITY PLAYLIST DATA
quality_playlists=`curl -s ${cdn_source}index.m3u8 | grep \.m3u8$`
max_quality=${quality_playlists%%.m3u8*}


## GET CHUNK DATA
chunks=`curl -s ${cdn_source}${max_quality}.m3u8 | grep -v '#'`



## PARSE CHUNKS
#create download marker file
echo ${script_pid} > data/downloading/${site}.${short_name}

#reset counter
chunk_max=0
for i in ${chunks}; do let "chunk_max=${chunk_max}+1"; done
for i in ${chunks}; do
	let "count=${count}+1"
	output_chunk=`printf "%0${#chunk_max[0]}d" ${count}`
	if [ ${pissoff_mode} = "yes" ]
	then
		curl -s -o tmp/${script_pid}/chunks/${output_chunk}.ts ${cdn_source}${i} &
	else
		curl -s -o tmp/${script_pid}/chunks/${output_chunk}.ts ${cdn_source}${i}
	fi
done
wait

## MERGE FILES
cat tmp/${script_pid}/chunks/* > tmp/${script_pid}/merged.ts
rm -r "tmp/${script_pid}/chunks"


## copy or convert output

if [ ${convert} = "yes" ]
then
	ffmpeg -loglevel quiet -y -threads ${enc_threads} -v warning -i "tmp/${script_pid}/merged.ts" -c:v ${enc_video} -preset ${enc_preset} ${enc_extras} -crf 22 -c:a ${enc_audio} -f ${enc_container} "tmp/${script_pid}/${short_name}.${enc_container}" 2>&1
	rm "tmp/${script_pid}/merged.ts"
	mv "tmp/${script_pid}/${short_name}.${enc_container}" "output/${site}/${long_name}.${enc_container}" 
	rm -r tmp/${script_pid}
else
	enc_container="ts"
	mv "tmp/${script_pid}/merged.ts" "tmp/${script_pid}/${short_name}.${enc_container}"
	mv "tmp/${script_pid}/${short_name}.${enc_container}" "output/${site}/${long_name}.${enc_container}"
	rm -r tmp/${script_pid}
fi
rm data/downloading/${site}.${short_name}
echo "${site}/${short_name}" >> data/completed.downloads

exit 0
