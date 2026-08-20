require "./spec_helper"
require "json"

# Runs the official ECMA-427 conformance suite vendored under
# spec/fixtures/purl-spec (see the README there for how to refresh it).
#
# Each case has a `test_type`:
#   parse    - parse `input` and compare the resulting components
#   build    - construct from `input`'s components and compare `to_s`
#   validate - parse `input` and compare `to_s` against the canonical form
#
# A case with `expected_failure` must raise `Purl::Error`.

# Official cases this library deliberately does not pass. Each entry names
# the exact case (description plus `test_type`) and says why, so the list
# stays honest rather than turning into a dumping ground for anything
# inconvenient.
#
# All of them come down to two places where the suite contradicts a
# normative rule this library follows instead:
#
#  1. ECMA-427 says a qualifier "key shall be composed only of lowercase
#     ASCII letters and numbers, period '.', dash '-' and underscore '_'",
#     so a purl carrying `Platform=java` is invalid. The suite agrees in
#     gem-test and rpm-test (both `required`, both `expected_failure`) but
#     the older maven cases still expect the key to be silently downcased.
#     The `recommended` cases below are remediation guidance — the group is
#     defined as showing "how to remediate or normalize [common problems] in
#     order to pass 'required' tests" — not a parser requirement.
#  2. git-definition.json declares the namespace and name `case_sensitive:
#     true`, so their case is preserved. One `recommended` case expects them
#     lowercased instead.
KNOWN_UNSUPPORTED = {
  "gem-test.json" => [
    {"Ruby gems can use qualifiers. Roundtrip an input purl to canonical.", "validate"},
  ],
  "maven-test.json" => [
    {"maven often uses qualifiers. Roundtrip an input purl to canonical using mixedcase type", "validate"},
    {"maven often uses qualifiers here mixedcase type", "parse"},
    {"maven pom reference. Roundtrip an input purl to canonical.", "validate"},
    {"maven pom reference", "parse"},
  ],
  "rpm-test.json" => [
    {"rpm often use qualifiers. Roundtrip an input purl to canonical.", "validate"},
  ],
  "git-test.json" => [
    {"git namespace and name should be lowercased. Validate an input purl.", "validate"},
  ],
}

private def string_or_nil(value : JSON::Any?) : String?
  value.try(&.as_s?)
end

private def qualifiers_of(object : JSON::Any) : Hash(String, String)?
  hash = object["qualifiers"]?.try(&.as_h?)
  return if hash.nil? || hash.empty?
  hash.transform_values(&.as_s)
end

private def build_from(object : JSON::Any) : Purl::PackageURL
  Purl::PackageURL.new(
    string_or_nil(object["type"]?) || "",
    string_or_nil(object["namespace"]?),
    string_or_nil(object["name"]?) || "",
    string_or_nil(object["version"]?),
    qualifiers_of(object),
    string_or_nil(object["subpath"]?),
  )
end

private def components_of(purl : Purl::PackageURL)
  {purl.type, purl.namespace, purl.name, purl.version, purl.qualifiers, purl.subpath}
end

private def expected_components(object : JSON::Any)
  {
    object["type"].as_s.downcase,
    string_or_nil(object["namespace"]?),
    object["name"].as_s,
    string_or_nil(object["version"]?),
    qualifiers_of(object),
    string_or_nil(object["subpath"]?),
  }
end

private def unsupported?(file : String, description : String, kind : String) : Bool
  # The suite reuses a base description and appends a ". Roundtrip ..."
  # suffix for the derived cases, so both halves of the pair must match.
  KNOWN_UNSUPPORTED.fetch(File.basename(file)) { return false }
    .any? { |(d, k)| d == description && k == kind }
end

describe "purl-spec conformance suite" do
  fixtures = Dir.glob(File.join(__DIR__, "fixtures", "purl-spec", "**", "*.json")).sort
  fixtures.should_not be_empty

  fixtures.each do |path|
    JSON.parse(File.read(path))["tests"].as_a.each_with_index do |test, index|
      description = test["description"].as_s
      kind = test["test_type"].as_s
      group = test["test_group"].as_s
      next if unsupported?(path, description, kind)

      it "#{File.basename(path)} ##{index} #{group} #{kind}: #{description}" do
        expect_failure = test["expected_failure"]?.try(&.as_bool?) || false

        if expect_failure
          expect_raises(Purl::Error) do
            case kind
            when "build" then build_from(test["input"])
            else              Purl::PackageURL.parse(test["input"].as_s)
            end
          end
          next
        end

        case kind
        when "parse"
          purl = Purl::PackageURL.parse(test["input"].as_s)
          components_of(purl).should eq(expected_components(test["expected_output"]))
        when "build"
          build_from(test["input"]).to_s.should eq(test["expected_output"].as_s)
        when "validate"
          purl = Purl::PackageURL.parse(test["input"].as_s)
          purl.to_s.should eq(test["expected_output"].as_s)
        else
          fail "unknown test_type #{kind.inspect}"
        end
      end
    end
  end
end
