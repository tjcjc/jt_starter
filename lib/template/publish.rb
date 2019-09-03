puts ENV["TRAVIS_BRANCH"]
if ENV["TRAVIS_BRANCH"].match /^([\d.])+$/
    system("which pod")
    system("echo 'begin publish'")
    system("pod repo add {{nickname}} https://github.com/{{nickname}}/Specs")
    system "/usr/local/bin/git -C /Users/travis/.cocoapods/repos/{{nickname}} remote remove origin"
    system "/usr/local/bin/git -C /Users/travis/.cocoapods/repos/{{nickname}} remote add origin https://{{nickname}}:$PUBLISH_KEY@github.com/{{nickname}}/Specs.git"
    system "/usr/local/bin/git -C /Users/travis/.cocoapods/repos/{{nickname}} fetch"
    system "/usr/local/bin/git -C /Users/travis/.cocoapods/repos/{{nickname}} branch --set-upstream-to=origin/master master"
    system "pod repo push {{nickname}} {{project_name}}.podspec --allow-warnings --verbose"
end