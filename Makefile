all:
	npm install
	npm run compile

compile:
	npm run compile

view: src/Main.elm media/main.js
	elm make src/Main.elm --output media/main.js
