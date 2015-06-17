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
	@./node_modules/.bin/mocha --recursive -R xunit test/ > test-reports.xml

clean: 
	rm -f $(targets)
