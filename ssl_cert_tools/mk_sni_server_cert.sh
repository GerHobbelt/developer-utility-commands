#!/bin/bash
#

if test $# -lt 1 ; then
    cat <<EOT
mk_server_cert FQDN [FQDN2 ...]

Create a new SSL Server Certificate using server's FQDN or set of FQDN alternates, like

   ./mk_server_cert.sh doc.mbh.com

or

   ./mk_server_cert.sh doc.mbh.com docu.mbh.com documentation.mbh.com

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
    # You are not running this script in the key store directory Server CA basedir.
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
    if test -d keys-and-certificates/21_server_CA ; then
      cd keys-and-certificates/21_server_CA
    elif test -d __local_key_store__/keys-and-certificates/21_server_CA ; then
      # does the developer-owned keystore exist already?
      cd __local_key_store__/keys-and-certificates/21_server_CA
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

NOTICE: we have located the SSL Server Certs & Keys store base directory at

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
# server, if it hasn't one already:
serverDir="$1"

certBaseDir="newcerts/$serverDir"

serverConf=$certBaseDir/31_server.conf

if ! test -d "$certBaseDir/private" ; then
    mkdir -p "$certBaseDir/private"
else
    # check if the key+cert already exist:
    
    if   test -s "$certBaseDir/private/servercert.p12"      \
      && test -s "$certBaseDir/private/bundled-servercert-and-private-key.pem"    \
      && test -s "$certBaseDir/private/pass.phrase.txt"     \
      && test -s "$certBaseDir/private/serverkey.pem"       \
      && test -s "$certBaseDir/servercert.pem"              \
    ; then
        cat <<EOT

NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE 

The Server Certificate & Private Key have already been generated previously for this server.

They reside here:

    $certBaseDir/private/bundled-servercert-and-private-key.pem
    $certBaseDir/private/servercert.p12
    $certBaseDir/private/serverkey.pem
    $certBaseDir/private/pass.phrase.txt
    $certBaseDir/servercert.pem


EOT
        exit 3
    fi
fi

if ! test -s "$serverConf" ; then
    cat $utildir/31.003_server_cert_template.conf | sed -e '/\[ req_distinguished_name \]/,/# *END: \[ req_distinguished_name \]/{d}' > "$serverConf"
    # create user-specific section:
    cat >> "$serverConf" <<EOT


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

#commonName                  = Moir-Brandts-Honk Public Test Server Bulk Virtual Hosting Certificate
#CN                          = Moir-Brandts-Honk Public Test Server Virtual Hosting Certificate
CN                          = $1 :: Server Certificate

emailAddress                = ger.hobbelt@mbh.com



[ req_attributes ]

unstructuredName            = Moir-Brandts-Honk Ltd.



# subjectAltName entries
# 
# Please note: all DNS names MUST resolve to the same IP address as the FQDN.
# (We are actually much more lenient than that as we have full control over the DNS and IP
# allocation of these domains and subdomains *and* we intend to create one SAN/Wildcard SSL cert
# for all our 'Mass Virtual Host' configured Internet Facing Server nodes as well.
# In other words: we don't mind that some of these domains may point to another one of our 
# public test/demo servers as all of them will be serving the very same SAN/Wildcard certificate:
# the key point is that 'on the Internet' we will own all domains and subdomains we list in this
# SAN section, while it doesn't matter all that much on a developer local node.)
#
# SAN certificates MAY carry wildcards!
[alt_names_for_server_cert]
#DNS.1   = copy:commonName

EOT

    # WARNING: this requires bash 3.x+
    for i in {1..$#} ; do
        echo "DNS.$i   = ${!i}"
    done

    cat >> "$serverConf" <<EOT

# The 2nd level domains are served elsewhere, hence they are not listed in the wildcards for this SAN cert.




# And MARK the end of the prompt=no sections' series so we can use SED to edit this entire blurb
# with ease in mk_server_cert.sh   :-)
#
# END: [ req_distinguished_name ]



EOT

else
    cat <<EOT



*** WARNING WARNING WARNING WARNING WARNING WARNING ***

Your server configuration has already been defined previously: we do NOT use your new input
but will use the existing data instead!


If this is not what you want to happen, hit Ctrl+C to abort this script. 
Otherwise hit the ENTER key to continue...
EOT
    read -n 1 -s
    echo ""
fi


echo "$serverConf":::

#cat "$serverConf"


cat <<EOT


Generating Server Certificate: $1  -->  $serverDir

EOT
  
# And now invoke the relevant Server Certificate initialization script:
$utildir/init_31_bulk_vhost_server_cert.sh "$1" "$serverConf"  "$serverDir"


