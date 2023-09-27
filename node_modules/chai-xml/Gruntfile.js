module.exports = function(grunt) {
    'use strict';

    //load npm tasks
    require('load-grunt-tasks')(grunt);

    grunt.initConfig({

        pkg: grunt.file.readJSON('package.json'),

        eslint : {
            plugin : {
                src : ['src/*.js'],
                options : {
                    configFile: '.eslintrc.js'
                }
            },
            test   : {
                src : ['test/*-spec.js'],
                options : {
                    configFile: 'test/.eslintrc.js'
                }
            }
        },
        mochaTest: {
            test: {
                options: {
                    reporter: 'spec'
                },
                src: ['test/**/*.js']
            }
        },
    });

    grunt.registerTask('lint', ['eslint:plugin', 'eslint:test']);
    grunt.registerTask('test', ['mochaTest:test']);
    grunt.registerTask('default', ['lint', 'test']);
};
