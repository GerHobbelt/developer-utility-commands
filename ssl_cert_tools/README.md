SSL/TLS CA / Certificate Utilities
==================================

>
> ** WARNING / NOTE **
> ====================  
>
> The official Moir-Brandts-Honk servers' and users' key and certificate material MUST be stored in the 
> separate `_key-material-for-administrators` repository and is only accessible to authorized
> administrators.
>
> On the other hand, the *tools* / *scripts* which create this type of key material are stored
> in the `environment_root` repository itself and are available to all Moir-Brandts-Honk personnel: after
> all, these tools are also useful for developers as now they can create/mimic the SSL
> certificate infrastructure on any nodes managed by themselves by creating a **local, completely
> independent, key/certificate collective**. These local, developer-owned, key/certificate stores
> can be used to enable everyone involved
> to set up their development/test/evaluation environment such that it mimics our servers' setup
> as closely as possible. This is important as it reduces the number of 'nasty surprises' late
> in the development/test cycle due to differences in the development / server platforms.
>

The key / certificate storage structure
---------------------------------------

The 'developer-owned local keystore' is located in the `\<environment_root\>/__local_key_store__/`
directory.

The PKI organization is as follows:

```
root CA
  |
  +--- server 'issuer base CA'
  |        |
  |        +--- server certs CA
  |                 |
  |                 +--- ( SAN/Wildcard certificate for your server )
  |                 |
  |                 `--- ... other server certificates ...
  |
  +--- client 'issuer base CA'
           |
           +--- client certs CA
                    |
                    +--- user A :: client certificate
                    |
                    +--- user B :: client certificate
                    |
                    `--- ... other client certificates ...
```

The key material for each CA is organized in directories. Every CA store resides in a separate
directory:

CA name                       | directory name
------------------------------+---------------------------------------------
root CA                       | `00_root_CA`
server 'issuer base CA'       | `11_server_base_CA`
server certs CA               | `21_server_CA`
client 'issuer base CA'       | `12_client_base_CA`
client certs CA               | `22_client_CA`



