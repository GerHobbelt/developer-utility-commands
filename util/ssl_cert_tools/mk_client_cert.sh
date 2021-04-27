#!/bin/bash
#

if test $# -lt 1 || test $# -gt 2 ; then
    cat <<EOT
mk_client_cert NAME [EMAIL]

Create a new SSL Client Certificate using client's recognizable name or nick, like

   ./mk_client_cert.sh Ger.Hobbelt

EOT
    exit
fi


wd="$( pwd )";

# http://stackoverflow.com/questions/3572030/bash-script-absolute-path-with-osx/3572105#3572105
realpath() {
  [[ $1 = /* ]] && echo "$1" || echo "$wd/${1#./}"
}


utildir=$( realpath $(dirname $0) )


if ! test -d private ; then
    # You are not running this script in the key store directory Client CA basedir.
    # 
    #  We'll try to find the appropriate key store basedir: 
    owd="$( pwd )";
    
    cd $(dirname $0)

    # go to root of project
    cd ../..

    nwd=$( $utildir/../print-git-repo-base-directory.sh "$wd" )
    echo "git repository base directory: $nwd"
    cd "$nwd"

    # 'developer mode' vs. 'server administration mode' is automatically detected:
    # only when the repository you currently sit in (`_key-material-for-administrators`) has a
    # `keys-and-certificates` subdirectory will we switch to 'server admin mode'!
    if test -d keys-and-certificates/22_client_CA ; then
      cd keys-and-certificates/22_client_CA
    elif test -d __local_key_store__/keys-and-certificates/22_client_CA ; then
      # does the developer-owned keystore exist already?
      cd __local_key_store__/keys-and-certificates/22_client_CA
    fi

    nwd="$( pwd )";

    if ! test -d private ; then
        cat <<EOT

ERROR: you are running 

  $0

in the wrong directory: we don't see the mandatory 'private' directory in here!

THIS ACTION IS NOW ABORTING...

EOT
        exit 1
    else
        cat <<EOT

NOTICE: we have located the SSL Client Certs & Keys store base directory at

  $nwd

If you don't agree, hit Ctrl+C at the prompt; hit ENTER to continue...

EOT
        read -n 1 -s
        echo ""
    fi
fi





# We don't want to be bothered with constructing a 'openssl ca -subj=...' commandline, which
# isn't going to work anyway because we use the -config option too: see the comments at
# http://superuser.com/questions/226192/openssl-without-prompt
#
# Hence, instead, we take the blunt route and generate a configuration file *copy* for every
# user, if he/she hasn't one already:
userDir=$( echo "$1" | sed -e 's/[^a-zA-Z0-9()@ ._-]/_/g' -e 's/[_-]+/_/g' -e 's/^\./EVIL_/' -e 's/\.\$/_EVIL/' )

certBaseDir="newcerts/$userDir"

userConf=$certBaseDir/32_client.conf

if test -z "$2" ; then
    email=$( echo "$1" | sed -e 's/[^a-zA-Z0-9]/./g' -e 's/[.]+/./g' -e 's/^\.//' -e 's/\.\$//' )@mbh.com
else
    email=$2
fi

if ! test -d "$certBaseDir/private" ; then
    mkdir -p "$certBaseDir/private"
else
    # check if the key+cert already exist:
    
    if   test -s "$certBaseDir/private/clientcert.p12"      \
      && test -s "$certBaseDir/private/bundled-clientcert-and-private-key.pem"    \
      && test -s "$certBaseDir/private/pass.phrase.txt"     \
      && test -s "$certBaseDir/private/clientkey.pem"       \
      && test -s "$certBaseDir/clientcert.pem"              \
    ; then
        cat <<EOT

NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE 

The Client Certificate & Private Key have already been generated previously for this user.

They reside here:

    $certBaseDir/private/bundled-clientcert-and-private-key.pem
    $certBaseDir/private/clientcert.p12
    $certBaseDir/private/clientkey.pem
    $certBaseDir/private/pass.phrase.txt
    $certBaseDir/clientcert.pem


EOT
        exit 3
    fi
fi

if ! test -s "$userConf" ; then
    cat $utildir/32.002_client_cert_template.conf | sed -e '/\[ req_distinguished_name \]/,/# *END: \[ req_distinguished_name \]/{d}' > "$userConf"
    # create user-specific section:
    cat >> "$userConf" <<EOT


[ req_distinguished_name ]
# prompt=no

#countryName                 = NL
C                           = NL

#stateOrProvinceName         = Zuid Holland
ST                          = Zuid Holland

#localityName                = Den Haag
L                           = Den Haag

#0.organizationName          = Moir-Brandts-Honk Ltd.
O                           = Moir-Brandts-Honk Ltd.

#organizationalUnitName      = Security Office
OU                          = Security Office :: User Management

#commonName                  = You As Developer :: Moir-Brandts-Honk Development Client Authentication Certificate
CN                          = $1 :: Client Certificate

emailAddress                = $email



[ req_attributes ]

unstructuredName            = Moir-Brandts-Honk Ltd.




# And MARK the end of the prompt=no sections' series so we can use SED to edit this entire blurb
# with ease in mk_client_cert.sh   :-)
#
# END: [ req_distinguished_name ]



EOT

else
    cat <<EOT



*** WARNING WARNING WARNING WARNING WARNING WARNING ***

Your user configuration has already been defined previously: we do NOT use your new input
but will use the existing data instead!


If this is not what you want to happen, hit Ctrl+C to abort this script. 
Otherwise hit the ENTER key to continue...
EOT
    read -n 1 -s
    echo ""
fi


echo "$userConf":::

#cat "$userConf"


cat <<EOT


Generating Client Certificate: $1  -->  $userDir

EOT
  
# And now invoke the relevant Client Certificate initialization script:
$utildir/init_32_client_cert.sh "$1" "$userConf"  "$userDir"



# openssl genrsa -aes256 -out $1.key 4096
# openssl req -config ../_server.workfiles/openssl.cnf -new -key $1.key -out client-cert.csr

# # self-signed
# openssl x509 -req -days 365 -in client-cert.csr -CA mbh.ca.crt -CAkey mbh.ca.key -set_serial $2 -out $1.crt
# rm client-cert.csr
# openssl pkcs12 -export -clcerts -in $1.crt -inkey $1.key -out $1.p12

# cat > $1.INFO.txt <<EOT
# client certificate for trial-a.mbh.com

# private key passphrase follows on the line following the next '---' line:

# ---
# EOT

# read -r -p "Enter passphrase again: " -d $'\n' passphrase
# echo $passphrase >> $1.INFO.txt

# cat >> $1.INFO.txt <<EOT
# ---

# EOT

