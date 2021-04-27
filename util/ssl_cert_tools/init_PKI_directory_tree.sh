#! /bin/bash
#


if test "$1" = "-h" ; then
  cat <<EOT

$0 [-h]

Generate the PKI directory tree in the current repository working space, if the directory
structure has not been generated yet.

This is the first script you must run when setting up your SSL PKI environment for working
with server and client certificates.


EOT
  exit 1
fi



wd="$( pwd )";

# http://stackoverflow.com/questions/3572030/bash-script-absolute-path-with-osx/3572105#3572105
realpath() {
  [[ $1 = /* ]] && echo "$1" || echo "$wd/${1#./}"
}



pushd $(dirname $0)                                                                                     2> /dev/null  > /dev/null
utildir="$( pwd )";

# go to root of project
cd ../..

wd=$( util/print-git-repo-base-directory.sh "$wd" )
echo "git repository base directory: $wd"
cd "$wd"

# 'developer mode' vs. 'server administration mode' is automatically detected:
# only when the repository you currently sit in (`_key-material-for-administrators`) has a
# `keys-and-certificates` subdirectory will we switch to 'server admin mode'!
if test -d keys-and-certificates ; then
  cd keys-and-certificates
elif test -d __local_key_store__/keys-and-certificates ; then
  # does the developer-owned keystore exist already?
  cd __local_key_store__/keys-and-certificates
else
  cat <<EOT

## NOTICE ##

You are currently running in LOCAL DEVELOPER MODE and the keystore DOES NOT EXIST YET in

    $wd/__local_key_store__/keys-and-certificates    

The PKI directory tree will be generated there. If this not what you want, then ABORT
this script by hitting CTRL+C; otherwise hit the ENTER key to proceed...

EOT
  read;

  mkdir -p __local_key_store__/keys-and-certificates
  cd __local_key_store__/keys-and-certificates
fi



mkd() {
  #echo mkd: $( pwd )/$@
  if ! test -d "$1" ; then
    mkdir "$1"
  fi
}

mkf() {
  #echo mkf: $( pwd )/$@
  if ! test -f "$1" ; then
    f="$1";
    shift;
    if test $# != 0 ; then
      #echo mkf: CAT
      cat > "$f" <<EOT
$@
EOT
    else
      # guarantee that the file is zero-length:
      #echo mkf: TOUCH
      touch "$f"
    fi
  fi
}



echo "Initializing PKI directory tree in: " $( pwd )


# follow the README where the CA/PKI directory layout is documented:
for d in \
        00_root_CA \
        11_server_base_CA \
        21_server_CA \
        12_client_base_CA \
        22_client_CA 
do
  mkd $d
  cd $d

  cat <<EOT

======================================================================================

Initializing CA: $d

EOT

  mkd certs                # Where the issued certs are kept
  mkd crl                  # Where the issued crl are kept

  mkf index.txt            # database index file.

  mkd newcerts             # default place for new certs.

  #mkf cacert.pem           # The CA certificate

  #mkf serial          01   # The current serial number

  mkf crlnumber       01   # the current crl number; must be commented out to leave a V1 CRL
  mkf crl.pem              # The current CRL

  mkd private
  #mkf private/cakey.pem    # The private key
  mkf private/.rand        # private random number file

  mkd csr_log              # log all CSRs sent to this CA here

  # determine the parent level CA config file:
  case "$d" in
  "11_server_base_CA" )
    parentCfg="$utildir/00_root_CA.conf"
    parentDir="../00_root_CA"
    ;;

  "21_server_CA" )
    parentCfg="$utildir/11_server_base_CA.conf"
    parentDir="../11_server_base_CA"
    ;;

  "12_client_base_CA" )
    parentCfg="$utildir/00_root_CA.conf"
    parentDir="../00_root_CA"
    ;;

  "22_client_CA" )
    parentCfg="$utildir/12_client_base_CA.conf"
    parentDir="../12_client_base_CA"
    ;;

  * )
    parentCfg=""
    parentDir=""
    ;;
  esac
  
  # And now invoke the relevant CA initialization script:
  $utildir/init_$d.sh $utildir/$d.conf "$parentCfg" "$parentDir"

  cd ..
done




# create the 'default' server certificates for the development / test environments:
cd "21_server_CA"
parentCfg="$utildir/21_server_CA.conf"
for d in \
        31.001_dev_bulk_vhost \
        31.002_public_bulk_vhost
do
  cat <<EOT

======================================================================================

Generating Server Certificate: $d

EOT
  
  # And now invoke the relevant Server Certificate initialization script:
  $utildir/init_31_bulk_vhost_server_cert.sh $d $utildir/${d}_server_cert.conf  $d
done
cd ..



# create the 'default' client certificates for the development / test environments:
cd "22_client_CA"
parentCfg="$utildir/22_client_CA.conf"
for d in \
        32.001_this_developer 
do
  cat <<EOT

======================================================================================

Generating Client Certificate: $d

EOT
  
  # And now invoke the relevant Client Certificate initialization script:
  $utildir/init_32_client_cert.sh $d $utildir/${d}_client_cert.conf  $d
done

# and generate a client certificate for the developer who owns this workstation...
devName=$( $utildir/../git_print_repo_info.sh -m )
$utildir/mk_client_cert.sh "$devName"

cd ..




cat <<EOT

======================================================================================

Producing the DEVELOPER ONLY Apache certificates + keys directory organization used by
  
    ssl-vhosts-bulk.conf

on your development machine.

EOT
$utildir/init_31_apache_conf_dir_organization.sh 31.001_dev_bulk_vhost  apache_4_dev




cat <<EOT

======================================================================================

Producing the TEST SERVERS ONLY Apache certificates + keys directory organization used by
  
    ssl-vhosts-bulk.conf

on the Internet facing test server machines.

EOT
$utildir/init_31_apache_conf_dir_organization.sh 31.002_public_bulk_vhost  apache_4_public_test
  
  


popd                                                                                                    2> /dev/null  > /dev/null
