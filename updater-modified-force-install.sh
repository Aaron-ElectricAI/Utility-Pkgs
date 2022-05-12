#!/bin/bash

#Install at /home/ubuntu/ssl/updater.sh

updatecerts() {
  echo "Updating cert in 1 second..."
  sleep 1

  #Create pkcs version of pem files
  openssl pkcs12 -export -in fullchain.pem -inkey privkey.pem -out pkcs.p12 -name jsstomcat -passout pass:sslcertsforlifenowgodrinktea

  set -x

  #Pause tomcat...
  /usr/local/bin/jamf-pro server stop

  # backup old keystore file
  cp /usr/local/jss/tomcat/.keystore /usr/local/jss/tomcat/.keystore.old

  # Delete all current certs
  TOMCAT_ALIAS=$(keytool -list -v --keystore "/usr/local/jss/tomcat/.keystore" -storepass "changeit" | grep Alias | cut -d ' ' -f3)
  for ALIAS in $TOMCAT_ALIAS; do
      keytool -delete -alias "$ALIAS" -storepass "changeit" -keystore "/usr/local/jss/tomcat/.keystore"
  done

  # keytool -delete -alias "jsstomcat" -storepass "changeit" -keystore "/usr/local/jss/tomcat/.keystore"
  keytool -importkeystore -srcstorepass "sslcertsforlifenowgodrinktea" -deststorepass "changeit" -destkeypass "changeit" -srckeystore /home/ubuntu/ssl/pkcs.p12 -srcstoretype PKCS12 -destkeystore /usr/local/jss/tomcat/.keystore
  keytool -import -trustcacerts -alias jsstomcat -deststorepass "changeit" -file /home/ubuntu/ssl/fullchain.pem -noprompt -keystore "/usr/local/jss/tomcat/.keystore"

  #prevents "There was a problem communicating with a push server" errors
  sudo /var/lib/dpkg/info/ca-certificates-java.postinst configure

  #Starting Tomcat
  /usr/local/bin/jamf-pro server start

  #Copy most recent pem files to old files, so we don't constantly re-update the certs
  #cp /home/ubuntu/ssl/fullchain.pem /home/ubuntu/ssl/old_fullchain.pem
  #cp /home/ubuntu/ssl/privkey.pem /home/ubuntu/ssl/old_privkey.pem

  # get the first touch penalty out of the way
  wget --no-check-certificate https://127.0.0.1:8443/
}



echo $(date)

#Make sure we're running as sudo
if [ "$EUID" -ne 0 ]
  then echo "Please run as root / use sudo"
  exit
fi

pushd /home/ubuntu/ssl

#COPY fullchain.pem and privkey.pem FROM S3
aws s3 cp s3://ai.electric.jamf/ssl/fullchain.pem /home/ubuntu/ssl/fullchain.pem
aws s3 cp s3://ai.electric.jamf/ssl/privkey.pem /home/ubuntu/ssl/privkey.pem

#Make sure we got an actual file
if [ $(cat /home/ubuntu/ssl/privkey.pem | wc -l) -le 1 ];
then
  echo "Couldn't get private key file from s3, exiting"
  exit;
fi
if [ $(cat /home/ubuntu/ssl/fullchain.pem | wc -l) -le 1 ];
then
  echo "Couldn't get chain key file from s3, exiting"
  exit;
fi

#Figure out if we need to do a cert update
#if [ $(diff /home/ubuntu/ssl/old_fullchain.pem /home/ubuntu/ssl/fullchain.pem | wc -l) -ge 1 ]; then
  #updatecerts
#elif [ $(diff /home/ubuntu/ssl/old_privkey.pem /home/ubuntu/ssl/privkey.pem | wc -l) -ge 1 ]; then
  #updatecerts
#else
  #echo "No need to update cert, pem files haven't changed"
#fi

# skipping the above if statement to run the updatecerts() function
updatecerts

popd
