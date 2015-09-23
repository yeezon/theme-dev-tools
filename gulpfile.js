
// Require
var gulp  = require('gulp'),
    bSync = require('browser-sync'),
    toys  = require('gulp-load-plugins')();    // Auto require for package.json

// Setting
var rootDir  = './',
    rootSrc  = rootDir + 'src/',
    rootDist = rootDir + 'dist/Electron\.app/Contents/Resources/default_app/',
    ignoreTypes = 'styl|coffee|jade',
    conf = {
      copy: {
        watch: rootSrc + '**/*.!(' + ignoreTypes + ')',
        src  : rootSrc + '**/*.!(' + ignoreTypes + ')',
        dist : rootDist
      }
    };

// Auto Setting
(function() {
  var i, type,
      ignoreTypeList = ignoreTypes.split('|');

  for (i in ignoreTypeList) {
    type = ignoreTypeList[i];
    if (!conf[type]) {
      conf[type] = {
        watch: rootSrc + '**/*.' + type,
        src  : rootSrc + '**/*.' + type,
        dist : rootDist
      }
    }
  }
})();

// Server
var reload = bSync({
    server: {
      baseDir: rootDist,
      directory: true
    },
    port: 8181,
    open: false,
    injectChanges: true,
    ghostMode: false,
    ui: false
  }).reload;

// ### Tasks ### //

// Copy
gulp.task('copy', function() {
  gulp.src(conf.copy.src)
    .pipe(toys.plumber())
    .pipe(toys.cached(conf.copy.dist))
    .pipe(gulp.dest(conf.copy.dist))
    .pipe(reload({stream: true}));
});

// Stylus
gulp.task('stylus', function () {
  gulp.src(conf.styl.src)
    .pipe(toys.plumber())
    .pipe(toys.cached(conf.styl.dist))
    .pipe(toys.stylus())
    .pipe(gulp.dest(conf.styl.dist))
    .pipe(reload({stream: true}))
    .pipe(toys.rename({ suffix: '.min' }))
    .pipe(toys.minifyCss({ keepBreaks: true }))
    .pipe(gulp.dest(conf.styl.dist))
    .pipe(reload({stream: true}));
});

// Coffee
gulp.task('coffee', function () {
  gulp.src(conf.coffee.src)
    .pipe(toys.plumber())
    .pipe(toys.cached(conf.coffee.dist))
    .pipe(toys.coffee())
    .pipe(toys.jshint('jshintrc.json'))
    .pipe(toys.jshint.reporter('default'))
    .pipe(gulp.dest(conf.coffee.dist))
    .pipe(reload({stream: true}))
    .pipe(toys.rename({ suffix: '.min' }))
    .pipe(toys.uglify())
    .pipe(gulp.dest(conf.coffee.dist))
    .pipe(reload({stream: true}));
});

// Jade
gulp.task('jade', function() {
  gulp.src(conf.jade.src)
    .pipe(toys.plumber())
    .pipe(toys.cached(conf.jade.dist))
    .pipe(toys.jade({pretty: true}))
    .pipe(gulp.dest(conf.jade.dist))
    .pipe(reload({stream: true}));
});

// Watch
gulp.task('watch', function(){
  // Copy
  gulp.watch(conf.copy.watch, ['copy']);
  // Stylus
  gulp.watch(conf.styl.watch, ['stylus']);
  // Coffee
  gulp.watch(conf.coffee.watch, ['coffee']);
  // Jade
  gulp.watch(conf.jade.watch, ['jade']);
});

// Default Task
gulp.task('default', function(){
  gulp.start(['copy', 'stylus', 'coffee', 'jade', 'watch']);
});
