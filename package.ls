name: \laweasyread-data
version: \0.0.1
contributors:
    * 'ChangZhuo Chen <czchen@gmail.com>'
      ...
scripts:
    prepublish: "node prepublish.js"
    test: "node test.js"
engine:
    node: \0.10.x
dependencies:
    async: \~0.2.6
    file : \~0.2.1
    \fs-tools : \~0.2.10
    mkdirp: \~0.3.5
    moment: \~2.0.0
    mongodb: \~1.2.14
    optimist: \~0.3.5
    request: \~2.16.6
    sprintf: \~0.1.1
    shelljs: \~0.1.2
devDependencies:
    LiveScript: \~1.1.1
    should: \~1.2.2
licenses:
    * type: \MIT
      url: \https://github.com/g0v/laweasyread-data/blob/master/LICENSE
repository:
    type: \git
    url: \http://github.com/g0v/laweasyread-data
bugs:
    url: \https://github.com/g0v/laweasyread-data/issues
