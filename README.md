# LiC Application - in development
This is a POC for the Literature in Context project in eXist-db.

## Instructions for installation. 
- run ant from LiC-app 
- Drop generated .xar package into eXist-db's package manager
- Update permissions on LiC/modules/lib/coursepack.xql
  in eXide: 
  `sm:chmod(xs:anyURI('/db/apps/LiC/modules/lib/coursepack.xql'), "rwsrwxr-x")`

- Go to http://localhost:8080/exist/apps/LiC/index.html

  
  

