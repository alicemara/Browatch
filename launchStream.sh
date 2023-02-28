#!/bin/bash

[ -e pipe ] && rm pipe

mkfifo pipe

#Create a video ID from the time

VID=$(date '+%M%S')
#variables for keys for encoding
openssl rand -hex 16 > media.key
openssl rand -hex 16 > keyid.txt
key=$(cat media.key)
keyid=$(cat keyid.txt)

#variables for base64url conversions of keys for player
cat media.key | xxd -r -p | base64 | tr '/+' '_-' | tr -d '=' > keybase64.txt
cat keyid.txt | xxd -r -p | base64 | tr '/+' '_-' | tr -d '=' > keyidbase64.txt


keybase=$(cat keybase64.txt)
keyidbase=$(cat keyidbase64.txt)

# Create a web page with embedded dash.js player.

cat > ${VID}.html <<_PAGE_
<!DOCTYPE html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
  <meta name="description" content="">
  <meta name="viewport" content="width=device-width">
<script>
 /window.location.hash = "keyid=foo&key=bar"/

const parsedHash = new URLSearchParams(
 window.location.hash.substring(1)
);

var keyidsite = parsedHash.get("keyid");
var keysite = parsedHash.get("key");

;
</script>
      <style>
         body {
             background-color : black;
             margin : 0;
         }
         .videocontent {
             position: absolute;
             top: 50%;
             transform: translateY(-50%);
             width: 100%;
         }
      </style>
</head>
<body>
 <div class="videocontent">
            <video id="videoPlayer" width="100%" height="100%" controls preload="auto"  autoplay="true" muted="true"></video>
</div>

  <!-- Dash.js -->

  <script src="//reference.dashif.org/dash.js/v4.0.0/dist/dash.all.debug.js"></script>
<script>
            (function(){
                var url = "${VID}.mpd";
                var player = dashjs.MediaPlayer().create();
                
 		player.updateSettings({
            		streaming: {
                 		delay: {liveDelay: 3},
                 		liveCatchup: {
                    		enabled: true,
                    		maxDrift: 3,
                    		playbackRate: 0.5,
						},
				lowLatencyEnabled: true   
                  }			
            }
        );
                console.log(player.getSettings());

                setInterval(() => {
                  console.log('Live latency= ', player.getCurrentLiveLatency());
                  console.log('Buffer length= ', player.getBufferLength('video'));
                }, 3000);

     const protData = {
                "org.w3.clearkey": {
                        "clearkeys": {
                            [keyidsite] : keysite 
                        },
                }
        };
                player.initialize(document.querySelector("#videoPlayer"), url, true);
                player.setProtectionData(protData);
            })();

</script>

</body>
_PAGE_

curl -X PUT --upload-file ${VID}.html https://${1}/${VID}.html
curl -X PUT --upload-file ${VID}.html https://${1}/index.html
rm ${VID}.html 

echo "Do you want to specify a path to a file to stream? (yes/no) (If not, a stream will just be generated with a test pattern as a demo)"
read answer

if [ "$answer" = "yes" ]; then
echo "Please enter the file path:"
read filepath

ffmpeg \
    -re \
    -hide_banner \
    -i ${filepath} \
    -filter_complex \
    "[0:v]format=yuv420p,split=4[1][2][3][4]; \
     [1]null[1out]; \
     [2]scale=iw/2:ih/2[2out]; \
     [3]scale=iw/3:ih/3[3out]; \
     [4]scale=iw/4:ih/4[4out]" \
    -map '[1out]' \
    -c:v:0 h264_videotoolbox \
    -b:v:0 5000k \
    -map '[2out]' \
    -c:v:1 h264_videotoolbox \
    -b:v:1 1500k \
    -map '[3out]' \
    -c:v:2 h264_videotoolbox \
    -b:v:2 800k \
    -map '[4out]' \
    -c:v:3 h264_videotoolbox \
    -b:v:3 400k \
    -profile:v high \
    -force_key_frames "expr:gte(t,n_forced*3)" \
    -bf 3 \
    -refs 3 \
    -map 0:a \
    -c:a aac \
    -b:a 128k \
    -f mpegts \
    pipe: > pipe 2> encode.log &

else
ffmpeg \
    -f lavfi -i "testsrc=size=1920x1080:rate=24,format=yuv420p" \
    -f lavfi -i "sine=frequency=1000" \
    -filter_complex \
    "[0:v]format=yuv420p,split=4[1][2][3][4]; \
     [1]null[1out]; \
     [2]scale=iw/2:ih/2[2out]; \
     [3]scale=iw/3:ih/3[3out]; \
     [4]scale=iw/4:ih/4[4out]" \
    -map '[1out]' \
    -c:v:0 h264_videotoolbox \
    -b:v:0 5000k \
    -map '[2out]' \
    -c:v:1 h264_videotoolbox \
    -b:v:1 1500k \
    -map '[3out]' \
    -c:v:2 h264_videotoolbox \
    -b:v:2 800k \
    -map '[4out]' \
    -c:v:3 h264_videotoolbox \
    -b:v:3 400k \
    -profile:v high \
    -force_key_frames "expr:gte(t,n_forced*3)" \
    -bf 3 \
    -refs 3 \
    -map 1:0 \
    -c:a aac \
    -b:a 128k \
    -f mpegts \
    pipe: > pipe 2> encode.log &

fi

./packager-osx-x64 \
   --io_block_size 65536 \
   --segment_duration 3 \
   --low_latency_dash_mode=true \
   --utc_timings "urn:mpeg:dash:utc:http-xsiso:2014"="https://time.akamai.com/?iso&ms",["urn:mpeg:dash:utc:http-ntp:2014"="time.google.com"] \
    in=pipe,stream=0,init_segment=https://${1}/${VID}_0_init.m4s,segment_template=https://${1}/${VID}-0-chunk-'$Number%05d$.m4s' \
    in=pipe,stream=1,init_segment=https://${1}/${VID}_1_init.m4s,segment_template=https://${1}/${VID}-1-chunk-'$Number%05d$.m4s' \
    in=pipe,stream=2,init_segment=https://${1}/${VID}_2_init.m4s,segment_template=https://${1}/${VID}-2-chunk-'$Number%05d$.m4s' \
    in=pipe,stream=3,init_segment=https://${1}/${VID}_3_init.m4s,segment_template=https://${1}/${VID}-3-chunk-'$Number%05d$.m4s' \
    in=pipe,stream=4,init_segment=https://${1}/${VID}_4_init.m4s,segment_template=https://${1}/${VID}-4-chunk-'$Number%05d$.m4s' \
   --clear_lead=0 \
   --enable_raw_key_encryption \
   --keys label=:key=${key}:key_id=${keyid} \
   --mpd_output https://${1}/${VID}.mpd \
    >/dev/null 2> packager.log &

echo "You'll have the link in just a moment..."
sleep 7

# open is a universal upener in OSX, will want to expand depending on host machine
open "https://${1}/${VID}.html#keyid=${keyidbase}&key=${keybase}"
echo "Here's a link to share!"
echo "https://${1}/${VID}.html#keyid=${keyidbase}&key=${keybase}"
