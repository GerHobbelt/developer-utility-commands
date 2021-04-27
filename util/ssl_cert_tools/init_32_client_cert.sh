#! /bin/bash
#
# ARGS: 32.dirname CAconf.file  [force.using.this.cert.directory]
# 

cat <<EOT

================================================================================
Initializing the $1 Client Certificate...

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
  # certBaseDir=newcerts/testclient1  
fi

if   test -s "$certBaseDir/private/clientcert.p12"      \
  && test -s "$certBaseDir/private/bundled-clientcert-and-private-key.pem"    \
  && test -s "$certBaseDir/private/pass.phrase.txt"     \
  && test -s "$certBaseDir/private/clientkey.pem"       \
  && test -s "$certBaseDir/clientcert.pem"              \
; then
  echo "UH-OH: THIS CLIENT CERTIFICATE DOES ALREADY EXIST!"
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
  # echo "Client" | od -t x1
  echo "436c69656e74000000000001" > "$serialFile"
fi


# If the private key has not been generated yet, generate it now.
# 
# The default is a 2048 bit key:
if ! test -s "$certBaseDir/private/clientkey.pem" ; then
  echo "Generating private key..."
  openssl genrsa -aes256 -passout file:$certBaseDir/private/pass.phrase.txt -out $certBaseDir/private/clientkey.pem 2048

  # Decrypt the private key and store this copy in the PEM format:
  #openssl rsa -passin file:$certBaseDir/private/pass.phrase.txt -in $certBaseDir/private/clientkey.pem -outform pem -out $certBaseDir/private/clientkey-decrypted.pem
fi


if ! test -s "$certBaseDir/clientcert.pem" ; then
  echo "Create a CSR for this client cert..."
  pwd
  echo openssl req -passin "file:$certBaseDir/private/pass.phrase.txt" -config "$2" -new -key "$certBaseDir/private/clientkey.pem" -out "$certBaseDir/private/clientcert.csr" -days 365
  openssl req -passin "file:$certBaseDir/private/pass.phrase.txt" -config "$2" -new -key "$certBaseDir/private/clientkey.pem" -out "$certBaseDir/private/clientcert.csr" -days 365

  # print the CSR
  openssl req -text -noout -verify -in "$certBaseDir/private/clientcert.csr"

  echo "Let the CLIENT SIGNING CA sign the certificate..."
  openssl ca -passin file:private/pass.phrase.txt -config "$2" -batch -in "$certBaseDir/private/clientcert.csr" -extensions client_cert -out "$certBaseDir/clientcert.pem"

  #openssl x509 -req -days 365 -in client-cert.csr -CA mbh.ca.crt -CAkey mbh.ca.key -set_serial $2 -out "$certBaseDir/clientcert.pem"
  #openssl pkcs12 -export -clcerts -in "$certBaseDir/clientcert.pem" -inkey $1.key -out "$certBaseDir/clientcert.p12"

  # print the certificate
  openssl x509 -in "$certBaseDir/clientcert.pem" -text
fi


# Client certs are often required to be deliverd in PKCS12 format:
if     ! test -s "$certBaseDir/private/clientcert.p12"                            \
    || ! test -s "$certBaseDir/private/bundled-clientcert-and-private-key.pem"    \
    || ! test -s "$certBaseDir/bundled-client.crt"                                \
    || ! test -s "$certBaseDir/bundled-client-ca-list.crt"                        \
; then
  echo "concat client + CA certs..."
  # trim off the text parts in those .pem files to produce a clean catalog:
  # https://www.digicert.com/ssl-support/pem-ssl-creation.htm
  openssl x509 -in "$certBaseDir/clientcert.pem"      -outform pem  > "$certBaseDir/collected-client-and-ca-certs.pem" 
  openssl x509 -in ../22_client_CA/cacert.pem         -outform pem >> "$certBaseDir/collected-client-and-ca-certs.pem"
  openssl x509 -in ../12_client_base_CA/cacert.pem    -outform pem >> "$certBaseDir/collected-client-and-ca-certs.pem"
  openssl x509 -in ../00_root_CA/cacert.pem           -outform pem >> "$certBaseDir/collected-client-and-ca-certs.pem"

  openssl x509 -in "$certBaseDir/clientcert.pem" -outform pem -out "$certBaseDir/client.crt"

  echo "create a PKCS12 certificate ..."
  # WARNING: Mac/OSX doesn't accept PKCS12 files without a password, so we use a dummy password here:
  #     'mbh'
  openssl pkcs12 -export -in "$certBaseDir/collected-client-and-ca-certs.pem" -name "Moir-Brandts-Honk Client Certificate" -inkey "$certBaseDir/private/clientkey.pem" -passin "file:$certBaseDir/private/pass.phrase.txt" -out "$certBaseDir/private/clientcert.p12" -passout pass:mbh

  # openssl pkcs12 -passin pass:mbh -in "$certBaseDir/private/clientcert.p12" -clcerts -nokeys -out "$certBaseDir/private/__cert.crt"
  # openssl pkcs12 -passin pass:mbh -in "$certBaseDir/private/clientcert.p12" -cacerts -nokeys -out "$certBaseDir/private/__ca-cert.crt"
  # openssl pkcs12 -passin pass:mbh -in "$certBaseDir/private/clientcert.p12" -nocerts -out "$certBaseDir/private/__private.key" -passout pass:mbh

  echo "create a PEM certificate ..."
  # Decrypt the private key and store this copy in the PEM format:
  openssl rsa -passin file:$certBaseDir/private/pass.phrase.txt -in $certBaseDir/private/clientkey.pem -outform pem -out "$certBaseDir/private/clientkey-decrypted.pem"
  cat "$certBaseDir/private/clientkey-decrypted.pem"     > "$certBaseDir/private/bundled-clientcert-and-private-key.pem"
  cat "$certBaseDir/collected-client-and-ca-certs.pem"  >> "$certBaseDir/private/bundled-clientcert-and-private-key.pem"

  echo "Generate a trimmed client certificate bundle..."
  cp "$certBaseDir/collected-client-and-ca-certs.pem"                          "$certBaseDir/bundled-client.crt"

  echo "Generate a trimmed client CA certificate bundle..."
  openssl x509 -in ../22_client_CA/cacert.pem         -outform pem  > "$certBaseDir/collected-ca-certs.pem"
  openssl x509 -in ../12_client_base_CA/cacert.pem    -outform pem >> "$certBaseDir/collected-ca-certs.pem"
  openssl x509 -in ../00_root_CA/cacert.pem           -outform pem >> "$certBaseDir/collected-ca-certs.pem"
  cp "$certBaseDir/collected-ca-certs.pem"            "$certBaseDir/bundled-client-ca-list.crt"

  # cleanup
  # rm -f "$certBaseDir/collected-client-and-ca-certs.pem"      \
  #       "$certBaseDir/collected-client-and-ca-certs-2.pem"    \
  #       "$certBaseDir/private/clientkey-decrypted.pem" \
  #       "$certBaseDir/client.crt"
fi

