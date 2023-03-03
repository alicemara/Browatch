# Browatch
Open source solution that enables you to co-watch a video from your computer while it is simultaneously streamed to your bro or bros in low latency with perfect synchronization and full privacy via end to end encryption.

Made to run on LINUX DEVICES JUST FOR YOU devices.
Running `aws_auto_setup.sh` will:
1) Verify you have the needed packages then either download or update them.
2) Set up & configure everything needed in AWS including a Browatch profile, and a creating a configured EC2 instance.  
3) SCPs needed files over the the EC2 instance and sets up a web server that will host a video player. 
4) Download the needed MacOS packager and start a stream of a desired file or a test pattern if no input is given.
5) Open a webpage with the player and stream and give a link that you can share with others so they can watch your stream.
