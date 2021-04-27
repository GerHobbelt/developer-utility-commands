#! /bin/bash
#


cat <<EOT

================================================================================
Initializing the root CA...

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


if ! test -s "$1" ; then
  cat <<EOT

ERROR: you have not specified a suitable openssl configuration file:

    $1

THIS ACTION IS NOW ABORTING...

EOT
  exit 1
fi




serialFile=serial



# if the passphrase file has not yet been created, generate it now:
if ! test -s private/pass.phrase.txt ; then
  cat <<EOT

The private key passphrase has not yet been specified for this entity. Please enter a suitable
passphrase at the prompt and then hit ENTER.

Note: if you simply hit ENTER, a random passphrase will be generated instead.

Enter passphrase:
EOT
  read line

  if test -z "$line" ; then
    echo "Autogenerating a random passphrase..."
    openssl rand -hex 32                            > private/pass.phrase.txt
  else
    echo "$line"                                    > private/pass.phrase.txt 
  fi
fi


# If the 'serial' file hasn't been generated yet, set it up with a global unique serial number
# (the 'global unique' aspect is not mandatory but it helps debugging certificate chains as the
# serials for all certificates are now unique: the Most Significant part of the Large Number
# is a hex-encoding string describing the cert 'type': each CA has it's own 'type' code)
if ! test -s "$serialFile" ; then
  # echo "Root CA" | od -t x1
  echo "526f6f74204341000000000001" > "$serialFile"
fi


# If the private key has not been generated yet, generate it now.
# 
# The default is a 4096 bit key:
if ! test -s private/cakey.pem ; then
  echo "Generating private key..."
  openssl genrsa -aes256 -passout file:private/pass.phrase.txt -out private/cakey.pem 4096

  # Decrypt the private key and store this copy in the PEM format:
  #openssl rsa -passin file:private/pass.phrase.txt -in private/cakey.pem -outform pem -out private/cakey-decrypted.pem
fi


if ! test -s cacert.pem ; then
  echo "Create a self-signed certificate for the root CA..."
  #openssl req -passin file:private/pass.phrase.txt -config "$1" -new -key private/cakey.pem -out private/cacert.csr
  openssl req -passin file:private/pass.phrase.txt -config "$1" -new -x509 -key private/cakey.pem -out cacert.pem -days 3650

  # print the CSR
  #openssl req -text -noout -verify -in private/cacert.csr

  # print the self-signed certificate
  #openssl x509 -in cacert.pem -text
fi


if ! test -s crl.pem ; then
  echo "Generate CRL..."
  openssl ca -passin file:private/pass.phrase.txt -config "$1" -gencrl -out crl.pem
  # However, do not the comment by @stm @ 2014 feb 06: RFC5280 requires CRLs to be presented in DER format
  # https://jamielinux.com/articles/2013/08/generate-certificate-revocation-list-revoke-certificates/
fi

