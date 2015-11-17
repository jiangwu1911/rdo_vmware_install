export ST_AUTH=http://192.168.206.157:8080/auth/v1
export ST_USER=user01
export ST_KEY=password

# Create a container
swift post testcon

# Upload file
swift upload testcon test1.sh

swift stat testcon

swift list testcon

swift download testcon test1.sh
