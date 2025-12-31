require "./spec_helper"

describe Purl do
  it "should have a version" do
    Purl::VERSION.should_not be_nil
  end

  describe Purl::PackageURL do
    describe "#to_s" do
      it "returns purl with all components" do
        p = Purl::PackageURL.new("npm", "@angular", "animation", "12.3.1", "repository_url=https://example.com", "src/main")
        p.to_s.should eq("pkg:npm/%40angular/animation@12.3.1?repository_url=https://example.com#src/main")
      end

      it "returns purl without namespace" do
        p = Purl::PackageURL.new("npm", nil, "lodash", "4.17.21", nil, nil)
        p.to_s.should eq("pkg:npm/lodash@4.17.21")
      end

      it "returns purl without version" do
        p = Purl::PackageURL.new("npm", nil, "lodash", nil, nil, nil)
        p.to_s.should eq("pkg:npm/lodash")
      end

      it "returns purl with only type and name" do
        p = Purl::PackageURL.new("pypi", nil, "requests", nil, nil, nil)
        p.to_s.should eq("pkg:pypi/requests")
      end

      it "encodes special characters in namespace" do
        p = Purl::PackageURL.new("npm", "@scope", "pkg", "1.0.0", nil, nil)
        p.to_s.should eq("pkg:npm/%40scope/pkg@1.0.0")
      end
    end

    describe ".parse" do
      it "parses a purl with all components" do
        p = Purl::PackageURL.parse("pkg:npm/%40angular/animation@12.3.1?repository_url=https://example.com#src/main")
        p.type.should eq("npm")
        p.namespace.should eq("@angular")
        p.name.should eq("animation")
        p.version.should eq("12.3.1")
        p.qualifiers.should eq("repository_url=https://example.com")
        p.subpath.should eq("src/main")
      end

      it "parses a purl without namespace" do
        p = Purl::PackageURL.parse("pkg:npm/lodash@4.17.21")
        p.type.should eq("npm")
        p.namespace.should be_nil
        p.name.should eq("lodash")
        p.version.should eq("4.17.21")
        p.qualifiers.should be_nil
        p.subpath.should be_nil
      end

      it "parses a purl without version" do
        p = Purl::PackageURL.parse("pkg:npm/lodash")
        p.type.should eq("npm")
        p.namespace.should be_nil
        p.name.should eq("lodash")
        p.version.should be_nil
        p.qualifiers.should be_nil
        p.subpath.should be_nil
      end

      it "parses maven style purl with namespace" do
        p = Purl::PackageURL.parse("pkg:maven/org.apache.commons/commons-lang3@3.12.0")
        p.type.should eq("maven")
        p.namespace.should eq("org.apache.commons")
        p.name.should eq("commons-lang3")
        p.version.should eq("3.12.0")
      end

      it "parses purl with qualifiers only" do
        p = Purl::PackageURL.parse("pkg:npm/lodash?vcs_url=git://github.com/lodash/lodash.git")
        p.type.should eq("npm")
        p.name.should eq("lodash")
        p.version.should be_nil
        p.qualifiers.should eq("vcs_url=git://github.com/lodash/lodash.git")
      end

      it "raises ArgumentError for invalid purl" do
        expect_raises(ArgumentError, "Invalid Package URL") do
          Purl::PackageURL.parse("invalid-purl")
        end
      end

      it "raises ArgumentError for purl without pkg scheme" do
        expect_raises(ArgumentError, "Invalid Package URL") do
          Purl::PackageURL.parse("npm/lodash@1.0.0")
        end
      end
    end

    describe "roundtrip" do
      it "can parse what it generates" do
        original = Purl::PackageURL.new("gem", nil, "rails", "7.0.0", nil, nil)
        parsed = Purl::PackageURL.parse(original.to_s)
        parsed.type.should eq(original.type)
        parsed.namespace.should eq(original.namespace)
        parsed.name.should eq(original.name)
        parsed.version.should eq(original.version)
      end

      it "can parse what it generates with namespace" do
        original = Purl::PackageURL.new("npm", "@rails", "actioncable", "7.0.0", nil, nil)
        parsed = Purl::PackageURL.parse(original.to_s)
        parsed.type.should eq(original.type)
        parsed.namespace.should eq(original.namespace)
        parsed.name.should eq(original.name)
        parsed.version.should eq(original.version)
      end
    end
  end
end
