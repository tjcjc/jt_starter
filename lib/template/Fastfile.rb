lane :ci_test do
    lint
    test
end

lane :lint do
    swiftlint(
        mode: :lint,                            # SwiftLint mode: :lint (default) or :autocorrect
        executable: "/usr/local/bin/swiftlint", # The SwiftLint binary path (optional). Important if you've installed it via CocoaPods
        # path: "Example",                  # Specify path to lint (optional)
        output_file: "test_output/swiftlint.result.xml",   # The path of the output file (optional)
        reporter: "junit",                       # The custom reporter to use (optional)
        config_file: ".swiftlint.yml",       # The path of the configuration file (optional)
    )
end

lane :test do
    scan(
        {{#is_pod}}
        workspace: "Example/{{project_name}}.xcworkspace",
        scheme: "{{project_name}}-Example",
        {{/is_pod}}
        {{^is_pod}}
        workspace: "{{project_name}}.xcworkspace",
        scheme: "{{project_name}}",
        {{/is_pod}}
        device: "iPhone Xʀ",

        # open_report(true)

        # clean(true)

        # Enable skip_build to skip debug builds for faster test performance
        # skip_build: true,
        code_coverage: true,
        output_types: "junit",
        output_files: "test.xml",
        output_directory: "test_output",
        # formatter: "xcpretty-json-formatter",
    )
end

## XCode 11 delete the report file
lane :coverage do
    xcov(
        {{#is_pod}}
        workspace: "Example/{{project_name}}.xcworkspace",
        scheme: "{{project_name}}-Example",
        {{/is_pod}}
        {{^is_pod}}
        workspace: "{{project_name}}.xcworkspace",
        scheme: "{{project_name}}",
        {{/is_pod}}
        output_directory: "test_output"
        #    exclude_targets: 'Demo.app',
        # minimum_coverage_percentage: 0.,
    )
end
