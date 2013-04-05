"use strict";

var optimist = require('optimist');
var path = require('path');
var shell = require('shelljs');

var bin = ['./node_modules', '.bin'].join(path.sep);

var lsc = [bin, 'lsc'].join(path.sep);
var mocha = [bin, 'mocha'].join(path.sep);
var jscoverage = [bin, 'jscoverage'].join(path.sep);

var compile = function (src) {
    for (var i = 0; i < src.length; ++i) {
        shell.exec(lsc + " -c " + src[i]);
    }
};

var create_cov_dst_path = function (src) {
    var ret = src.split(path.sep);
    ret[0] += '-cov';
    return ret.join(path.sep);
};

var generate_coverage = function (src) {
    var all_js = shell.find(src).filter(function (file) { return /\.js$/.test(file); });
    for (var i = 0; i < all_js.length; ++i) {
        shell.exec([
            jscoverage, all_js[i], create_cov_dst_path(all_js[i])
        ].join(' '));
    }
};

(function () {
    var argv = optimist
        .boolean(['coverage'])
        .default({
            'reporter': 'spec'
        })
        .argv;

    compile(['lib', 'test']);

    if (argv.coverage) {
        generate_coverage(['lib']);

        if (!/cov/.test(argv.reporter)) {
            argv.reporter = 'html-cov';
        }

        process.env.LAWEASYREAD_DATA_COV = true;
    }

    var ret = shell.exec(mocha + ' --no-colors --reporter ' + argv.reporter);
    shell.exit(ret.code);
})();
