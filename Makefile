.PHONY: test

# docs: $(patsubst %.md,%.html,$(wildcard *.md))

targets = lists.js reduce.js

all: $(targets)

%.js: src/%.coffee
	node_modules/.bin/mocha coffee -c -o . $<

%.html: %.md header.html footer.html
	cat header.html > $@
	pandoc $< >> $@
	cat footer.html >> $@

node_modules: package.json
	mkdir -p node_modules
	npm install

test: node_modules
	@JUNIT_REPORT_PATH=report.xml JUNIT_REPORT_STACK=1 ./node_modules/.bin/mocha \
		--reporter mocha-jenkins-reporter --compilers coffee:coffee-script/register || true
# @node_modules/.bin/mocha 

clean: 
	rm -f $(targets)
