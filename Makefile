.PHONY: test

# docs: $(patsubst %.md,%.html,$(wildcard *.md))

SOURCES= chapter1/*.coffee chapter3/*.coffee chapter-lambda-1/*.coffee test/*.coffee

%.js: src/%.coffee
	node_modules/.bin/mocha coffee -c -o . $<

%.html: %.md header.html footer.html
	cat header.html > $@
	pandoc $< >> $@
	cat footer.html >> $@

node_modules: package.json
	mkdir -p node_modules
	npm install

lint:
	coffeelint $(SOURCES)

test: clean node_modules
	@JUNIT_REPORT_PATH=test-reports.xml JUNIT_REPORT_STACK=1 ./node_modules/.bin/mocha \
		--reporter mocha-jenkins-reporter --compilers coffee:coffee-script/register || true

ltest: node_modules
	node_modules/.bin/mocha --compilers coffee:coffee-script/register

watch:
	while inotifywait $(SOURCES) ; do make test; done

clean: 
	rm -f report.xml test-reports.xml
