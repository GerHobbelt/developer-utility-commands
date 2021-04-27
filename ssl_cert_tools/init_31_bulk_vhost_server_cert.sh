#! /bin/bash
#
# ARGS: 31.dirname CAconf.file  [31.cert.basedir.dirname]
# 

cat <<EOT

================================================================================
Initializing the $1 Bulk Virtual Host Server Certificate...

EOT




if ! test -d private ; then
  cat <<EOT

ERROR: you are running 

  $0

in the wrong directory: we don't see the mandatory 'private' directory in here!

THIS ACTION IS NOW ABORTING...

EOT
  exit 1
fi


if test -z "$1" ; then
  cat <<EOT

ERROR: the (file)name of the certificate cannot be empty!

THIS ACTION IS NOW ABORTING...

EOT
  exit 1
fi


if ! test -s "$2" ; then
  cat <<EOT

ERROR: you have not specified a suitable openssl configuration file:

    $1

THIS ACTION IS NOW ABORTING...

EOT
  exit 1
fi







wd="$( pwd )";

# http://stackoverflow.com/questions/3572030/bash-script-absolute-path-with-osx/3572105#3572105
realpath() {
  [[ $1 = /* ]] && echo "$1" || echo "$wd/${1#./}"
}


# Generate a local directory structure per certificate to store 
# the private, public and passphrase files that go with that certificate:
# make sure the new certificate location is GUARANTEED UNIQUE, even when the
# same 'certificate filename' has been used before!
serialFile=serial
indexFile=index.txt
crlNumberFile=crlnumber
hh=$( cat $indexFile $serialFile $crlNumberFile | openssl sha1 -hex -sha256 | head -c 4 )
ts=$( date -Iseconds -u )
if test -z "$ts" ; then
  ts=$( date )
fi

if test -z "$3" ; then
  certBaseDir="newcerts/$( echo "$1.$ts.$hh" | sed -e 's/[^0-9a-zA-Z._-]/-/g' )"  
else
  certBaseDir="newcerts/$( echo "$3" | sed -e 's/[^0-9a-zA-Z._-]/-/g' )"  
  # certBaseDir=newcerts/testserver1  
fi

if   test -s "$certBaseDir/private/servercert.p12"      \
  && test -s "$certBaseDir/private/bundled-servercert-and-private-key.pem"    \
  && test -s "$certBaseDir/private/pass.phrase.txt"     \
  && test -s "$certBaseDir/private/serverkey.pem"       \
  && test -s "$certBaseDir/servercert.pem"              \
; then
  echo "UH-OH: THIS SERVER CERTIFICATE DOES ALREADY EXIST!"
  exit 2
fi
mkdir -p "$certBaseDir/private"


# if the passphrase file has not yet been created, generate it now:
if ! test -s "$certBaseDir/private/pass.phrase.txt" ; then
  cat <<EOT

The private key passphrase has not yet been specified for this entity. Please enter a suitable
passphrase at the prompt and then hit ENTER.

Note: if you simply hit ENTER, a random passphrase will be generated instead.

Enter passphrase:
EOT
  read line

  if test -z "$line" ; then
    echo "Autogenerating a random passphrase..."
    openssl rand -hex 32                            > "$certBaseDir/private/pass.phrase.txt"
  else
    echo "$line"                                    > "$certBaseDir/private/pass.phrase.txt" 
  fi
fi


# If the 'serial' file hasn't been generated yet, set it up with a global unique serial number
# (the 'global unique' aspect is not mandatory but it helps debugging certificate chains as the
# serials for all certificates are now unique: the Most Significant part of the Large Number
# is a hex-encoding string describing the cert 'type': each CA has it's own 'type' code)
if ! test -s "$serialFile" ; then
  # echo "Server" | od -t x1
  echo "536572766572000000000001" > "$serialFile"
fi


# If the private key has not been generated yet, generate it now.
# 
# The default is a 2048 bit key:
if ! test -s "$certBaseDir/private/serverkey.pem" ; then
  echo "Generating private key..."
  openssl genrsa -aes256 -passout file:$certBaseDir/private/pass.phrase.txt -out "$certBaseDir/private/serverkey.pem" 2048

  # Decrypt the private key and store this copy in the PEM format:
  #openssl rsa -passin file:$certBaseDir/private/pass.phrase.txt -in $certBaseDir/private/serverkey.pem -outform pem -out $certBaseDir/private/serverkey-decrypted.pem
fi


if ! test -s "$certBaseDir/servercert.pem" ; then
  echo "Create a CSR for this bulk vhost server cert..."
  pwd
  echo openssl req -passin "file:$certBaseDir/private/pass.phrase.txt" -config "$2" -new -key "$certBaseDir/private/serverkey.pem" -out "$certBaseDir/private/servercert.csr" -days 365
  openssl req -passin "file:$certBaseDir/private/pass.phrase.txt" -config "$2" -new -key "$certBaseDir/private/serverkey.pem" -out "$certBaseDir/private/servercert.csr" -days 365

  # print the CSR
  openssl req -text -noout -verify -in "$certBaseDir/private/servercert.csr"

  echo "Let the SERVER SIGNING CA sign the certificate..."
  openssl ca -passin file:private/pass.phrase.txt -config "$2" -batch -in "$certBaseDir/private/servercert.csr" -extensions bulk_vhosts_server_cert -out "$certBaseDir/servercert.pem"

  # print the certificate
  openssl x509 -in "$certBaseDir/servercert.pem" -text
fi


# Server certs are sometimes required to be deliverd in PKCS12 format:
if     ! test -s "$certBaseDir/private/servercert.p12"                            \
    || ! test -s "$certBaseDir/private/bundled-servercert-and-private-key.pem"    \
    || ! test -s "$certBaseDir/bundled-server.crt"                                \
    || ! test -s "$certBaseDir/bundled-server-ca-list.crt"                        \
; then
  echo "concat server + CA certs..."
  # trim off the text parts in those .pem files to produce a clean catalog:
  # https://www.digicert.com/ssl-support/pem-ssl-creation.htm
  openssl x509 -in "$certBaseDir/servercert.pem"      -outform pem  > "$certBaseDir/collected-server-and-ca-certs.pem" 
  openssl x509 -in ../21_server_CA/cacert.pem         -outform pem >> "$certBaseDir/collected-server-and-ca-certs.pem"
  openssl x509 -in ../11_server_base_CA/cacert.pem    -outform pem >> "$certBaseDir/collected-server-and-ca-certs.pem"
  openssl x509 -in ../00_root_CA/cacert.pem           -outform pem >> "$certBaseDir/collected-server-and-ca-certs.pem"

  openssl x509 -in "$certBaseDir/servercert.pem" -outform pem -out "$certBaseDir/server.crt"

  echo "create a PKCS12 certificate ..."
  openssl pkcs12 -export -in "$certBaseDir/collected-server-and-ca-certs.pem" -name "Moir-Brandts-Honk Server Certificate" -inkey "$certBaseDir/private/serverkey.pem" -passin "file:$certBaseDir/private/pass.phrase.txt" -out "$certBaseDir/private/servercert.p12" -passout pass:

  openssl pkcs12 -passin pass: -in "$certBaseDir/private/servercert.p12" -clcerts -nokeys -out "$certBaseDir/private/__cert.crt"
  openssl pkcs12 -passin pass: -in "$certBaseDir/private/servercert.p12" -cacerts -nokeys -out "$certBaseDir/private/__ca-cert.crt"
  openssl pkcs12 -passin pass: -in "$certBaseDir/private/servercert.p12" -nocerts -out "$certBaseDir/private/__private.key" -passout pass:

  echo "create a PEM certificate ..."
  # Decrypt the private key and store this copy in the PEM format:
  openssl rsa -passin file:$certBaseDir/private/pass.phrase.txt -in $certBaseDir/private/serverkey.pem -outform pem -out "$certBaseDir/private/serverkey-decrypted.pem"
  cat "$certBaseDir/private/serverkey-decrypted.pem"   > "$certBaseDir/private/bundled-servercert-and-private-key.pem"
  cat "$certBaseDir/collected-server-and-ca-certs.pem"           >> "$certBaseDir/private/bundled-servercert-and-private-key.pem"

  echo "Generate a trimmed server certificate bundle..."
  cp "$certBaseDir/collected-server-and-ca-certs.pem"  "$certBaseDir/bundled-server.crt"

  echo "Generate a trimmed client CA certificate bundle..."
  # https://www.digicert.com/ssl-support/pem-ssl-creation.htm
  openssl x509 -in ../21_server_CA/cacert.pem         -outform pem  > "$certBaseDir/collected-ca-certs.pem"
  openssl x509 -in ../11_server_base_CA/cacert.pem    -outform pem >> "$certBaseDir/collected-ca-certs.pem"
  openssl x509 -in ../00_root_CA/cacert.pem           -outform pem >> "$certBaseDir/collected-ca-certs.pem"
  cp "$certBaseDir/collected-ca-certs.pem"  "$certBaseDir/bundled-server-ca-list.crt"

  # cleanup
  # rm -f "$certBaseDir/collected-server-and-ca-certs.pem"      \
  #       "$certBaseDir/collected-server-and-ca-certs-2.pem"    \
  #       "$certBaseDir/private/serverkey-decrypted.pem" \
  #       "$certBaseDir/server.crt"
fi

