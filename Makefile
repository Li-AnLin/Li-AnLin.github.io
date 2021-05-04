build:
	docker build . -t jekyll-test

setup:
	docker rm -v --force jekyll_service
	setup.bat
	docker logs --tail 1000 -f jekyll_service