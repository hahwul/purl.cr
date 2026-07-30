require "./spec_helper"

describe Purl do
  it "should have a version" do
    Purl::VERSION.should_not be_nil
  end

  describe Purl::PackageURL do
    # =========================================================================
    # Validation tests
    # =========================================================================
    describe "validation" do
      it "raises on empty type" do
        expect_raises(Purl::Error, /type must not be empty/) do
          Purl::PackageURL.new("", nil, "name")
        end
      end

      it "raises on type starting with a digit" do
        expect_raises(Purl::Error, /must start with a letter/) do
          Purl::PackageURL.new("1npm", nil, "name")
        end
      end

      it "raises on type with invalid characters" do
        expect_raises(Purl::Error, /must start with a letter/) do
          Purl::PackageURL.new("n!pm", nil, "name")
        end
      end

      it "raises on empty name" do
        expect_raises(Purl::Error, /name must not be empty/) do
          Purl::PackageURL.new("npm", nil, "")
        end
      end

      it "raises on whitespace-only name" do
        expect_raises(Purl::Error, /name must not be empty/) do
          Purl::PackageURL.new("npm", nil, "  ")
        end
      end

      it "raises on invalid qualifier key starting with digit" do
        expect_raises(Purl::Error, /Invalid qualifier key/) do
          Purl::PackageURL.new("npm", nil, "pkg", nil, {"1bad" => "value"})
        end
      end

      it "raises on qualifier key with uppercase that is still invalid after lowercase" do
        expect_raises(Purl::Error, /Invalid qualifier key/) do
          Purl::PackageURL.new("npm", nil, "pkg", nil, {"1Bad" => "value"})
        end
      end

      it "allows valid type with dots and hyphens" do
        p = Purl::PackageURL.new("my-type.v2", nil, "pkg")
        p.type.should eq("my-type.v2")
      end

      it "allows valid type with plus sign" do
        p = Purl::PackageURL.new("c++", nil, "pkg")
        p.type.should eq("c++")
      end

      it "allows valid qualifier keys with dots, underscores, hyphens" do
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, {"repo_url" => "https://example.com", "vcs.type" => "git", "build-id" => "123"})
        p.qualifiers.should_not be_nil
      end
    end

    # =========================================================================
    # Type normalization
    # =========================================================================
    describe "type normalization" do
      it "normalizes type to lowercase" do
        p = Purl::PackageURL.new("NPM", nil, "lodash")
        p.type.should eq("npm")
      end

      it "normalizes mixed case type" do
        p = Purl::PackageURL.new("PyPI", nil, "requests")
        p.type.should eq("pypi")
      end
    end

    # =========================================================================
    # Type-specific name normalization
    # =========================================================================
    describe "name normalization" do
      it "normalizes pypi name: underscores to hyphens and lowercase" do
        p = Purl::PackageURL.new("pypi", nil, "My_Package")
        p.name.should eq("my-package")
      end

      it "normalizes npm name to lowercase" do
        p = Purl::PackageURL.new("npm", nil, "MyPackage")
        p.name.should eq("mypackage")
      end

      # Types whose definition declares the name case-insensitive.
      {"hex" => "Jason", "apk" => "Curl", "alpm" => "PacMan",
       "bitnami" => "WordPress", "luarocks" => "LUA-resty-http"}.each do |type, raw|
        it "normalizes #{type} name to lowercase" do
          Purl::PackageURL.new(type, nil, raw).name.should eq(raw.downcase)
        end
      end

      it "preserves cpan distribution name case" do
        p = Purl::PackageURL.new("cpan", "DROLSKY", "DateTime")
        p.name.should eq("DateTime")
      end

      it "preserves cran name case" do
        Purl::PackageURL.new("cran", nil, "A3").name.should eq("A3")
      end

      it "normalizes golang name to lowercase" do
        p = Purl::PackageURL.new("golang", "github.com/Package", "MyLib")
        p.name.should eq("mylib")
      end

      it "normalizes deb name to lowercase" do
        p = Purl::PackageURL.new("deb", "debian", "LibCurl")
        p.name.should eq("libcurl")
      end

      it "normalizes github name to lowercase" do
        p = Purl::PackageURL.new("github", "Owner", "Repo")
        p.name.should eq("repo")
      end

      it "normalizes bitbucket name to lowercase" do
        p = Purl::PackageURL.new("bitbucket", "Owner", "Repo")
        p.name.should eq("repo")
      end

      it "preserves maven name case" do
        p = Purl::PackageURL.new("maven", "org.apache", "CommonsLang")
        p.name.should eq("CommonsLang")
      end

      it "preserves gem name case" do
        p = Purl::PackageURL.new("gem", nil, "ActiveRecord")
        p.name.should eq("ActiveRecord")
      end

      it "preserves nuget name case" do
        p = Purl::PackageURL.new("nuget", nil, "Newtonsoft.Json")
        p.name.should eq("Newtonsoft.Json")
      end

      it "normalizes composer name to lowercase" do
        p = Purl::PackageURL.new("composer", "Framework", "Laravel")
        p.name.should eq("laravel")
      end

      it "normalizes oci name to lowercase" do
        p = Purl::PackageURL.new("oci", nil, "Debian")
        p.name.should eq("debian")
      end

      it "normalizes pub name to lowercase and replaces non-[a-z0-9_] chars with underscore" do
        p = Purl::PackageURL.new("pub", nil, "Flutter_Lints")
        p.name.should eq("flutter_lints")
      end

      it "replaces hyphens and dots in pub name with underscores" do
        p = Purl::PackageURL.new("pub", nil, "my-cool.pkg")
        p.name.should eq("my_cool_pkg")
      end
    end

    # =========================================================================
    # Type-specific namespace normalization
    # =========================================================================
    describe "namespace normalization" do
      it "normalizes npm namespace to lowercase" do
        p = Purl::PackageURL.new("npm", "@Angular", "core")
        p.namespace.should eq("@angular")
      end

      it "normalizes golang namespace to lowercase" do
        p = Purl::PackageURL.new("golang", "GitHub.com/MyOrg", "mylib")
        p.namespace.should eq("github.com/myorg")
      end

      it "normalizes deb namespace to lowercase" do
        p = Purl::PackageURL.new("deb", "Debian", "curl")
        p.namespace.should eq("debian")
      end

      it "normalizes rpm namespace to lowercase" do
        p = Purl::PackageURL.new("rpm", "Fedora", "curl")
        p.namespace.should eq("fedora")
      end

      it "normalizes github namespace to lowercase" do
        p = Purl::PackageURL.new("github", "MyOrg", "repo")
        p.namespace.should eq("myorg")
      end

      it "normalizes bitbucket namespace to lowercase" do
        p = Purl::PackageURL.new("bitbucket", "MyOrg", "repo")
        p.namespace.should eq("myorg")
      end

      # Types whose definition declares the namespace case-insensitive.
      {"hex" => "BitwiseOps", "apk" => "Alpine", "alpm" => "Arch",
       "luarocks" => "Kong", "qpkg" => "Blackberry"}.each do |type, raw|
        it "normalizes #{type} namespace to lowercase" do
          Purl::PackageURL.new(type, raw, "pkg").namespace.should eq(raw.downcase)
        end
      end

      it "uppercases the cpan namespace (CPANID)" do
        p = Purl::PackageURL.new("cpan", "drolsky", "DateTime")
        p.namespace.should eq("DROLSKY")
        p.to_s.should eq("pkg:cpan/DROLSKY/DateTime")
      end

      it "preserves maven namespace case" do
        p = Purl::PackageURL.new("maven", "org.Apache.Commons", "lang3")
        p.namespace.should eq("org.Apache.Commons")
      end

      it "normalizes composer namespace to lowercase" do
        p = Purl::PackageURL.new("composer", "Framework", "laravel")
        p.namespace.should eq("framework")
      end

      it "strips empty namespace segments so no '//' appears" do
        p = Purl::PackageURL.new("generic", "a//b", "name")
        p.namespace.should eq("a/b")
        p.to_s.should_not contain("//")
        p.to_s.should eq("pkg:generic/a/b/name")
      end

      it "keeps a constructed purl identical to its parsed form for collapsed namespaces" do
        constructed = Purl::PackageURL.new("generic", "a//b", "name")
        parsed = Purl::PackageURL.parse("pkg:generic/a//b/name")
        (constructed == parsed).should be_true
      end

      it "collapses a namespace of only slashes to nil" do
        p = Purl::PackageURL.new("generic", "//", "name")
        p.namespace.should be_nil
      end

      it "treats empty namespace as nil" do
        p = Purl::PackageURL.new("npm", "", "lodash")
        p.namespace.should be_nil
      end

      it "treats whitespace-only namespace as nil" do
        p = Purl::PackageURL.new("npm", "  ", "lodash")
        p.namespace.should be_nil
      end
    end

    # =========================================================================
    # Type-specific version normalization
    # =========================================================================
    describe "version normalization" do
      it "lowercases huggingface version (case-insensitive model ref)" do
        p = Purl::PackageURL.new("huggingface", "microsoft", "deberta", "MAIN-ABC123")
        p.version.should eq("main-abc123")
      end

      it "preserves huggingface name case while lowercasing version" do
        p = Purl::PackageURL.new("huggingface", "microsoft", "DialoGPT", "AbC")
        p.name.should eq("DialoGPT")
        p.version.should eq("abc")
      end

      it "lowercases oci version when it is a sha256 digest" do
        p = Purl::PackageURL.new("oci", nil, "debian", "sha256:ABC123DEF")
        p.version.should eq("sha256:abc123def")
      end

      it "leaves non-digest oci version untouched" do
        p = Purl::PackageURL.new("oci", nil, "debian", "Bullseye")
        p.version.should eq("Bullseye")
      end

      it "preserves version case for types without version normalization" do
        p = Purl::PackageURL.new("npm", nil, "pkg", "1.0.0-RC1")
        p.version.should eq("1.0.0-RC1")
      end

      # The version is a single opaque component, so `%2F` and `/` mean the
      # same character there — unlike namespace/name segments, where the
      # encoded slash must stay distinct from the segment separator.
      it "decodes an encoded slash in the version to a literal slash" do
        p = Purl::PackageURL.parse("pkg:npm/pkg@1%2F2")
        p.version.should eq("1/2")
      end

      it "round-trips a version containing an unencoded slash" do
        p = Purl::PackageURL.parse("pkg:npm/pkg@1/2")
        p.version.should eq("1/2")
        p.to_s.should eq("pkg:npm/pkg@1%2F2")
        (Purl::PackageURL.parse(p.to_s) == p).should be_true
      end

      it "treats an empty version as no version" do
        p = Purl::PackageURL.parse("pkg:npm/foo@")
        p.version.should be_nil
        p.to_s.should eq("pkg:npm/foo")
      end

      it "treats a whitespace-only version as no version" do
        p = Purl::PackageURL.new("npm", nil, "foo", "   ")
        p.version.should be_nil
        p.to_s.should eq("pkg:npm/foo")
      end

      it "considers a blank version equal to an absent one" do
        Purl::PackageURL.parse("pkg:npm/foo@").should eq(Purl::PackageURL.parse("pkg:npm/foo"))
      end

      it "round-trips a constructed version containing a slash" do
        original = Purl::PackageURL.new("generic", nil, "pkg", "refs/heads/main")
        original.to_s.should eq("pkg:generic/pkg@refs%2Fheads%2Fmain")
        (Purl::PackageURL.parse(original.to_s) == original).should be_true
      end
    end

    # =========================================================================
    # Qualifiers (Hash-based)
    # =========================================================================
    describe "qualifiers" do
      it "stores qualifiers as Hash(String, String)" do
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, {"repository_url" => "https://example.com"})
        p.qualifiers.should eq({"repository_url" => "https://example.com"})
      end

      it "normalizes qualifier keys to lowercase" do
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, {"Repository_URL" => "https://example.com"})
        p.qualifiers.should eq({"repository_url" => "https://example.com"})
      end

      it "removes qualifiers with empty values" do
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, {"key1" => "value1", "key2" => ""})
        p.qualifiers.should eq({"key1" => "value1"})
      end

      it "sets qualifiers to nil when all values are empty" do
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, {"key1" => "", "key2" => " "})
        p.qualifiers.should be_nil
      end

      it "sets qualifiers to nil when given nil" do
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, nil)
        p.qualifiers.should be_nil
      end

      it "preserves multiple qualifiers" do
        quals = {"arch" => "x86_64", "distro" => "ubuntu-20.04"}
        p = Purl::PackageURL.new("rpm", "fedora", "curl", "7.76.0", quals)
        p.qualifiers.should eq(quals)
      end
    end

    # =========================================================================
    # Subpath normalization
    # =========================================================================
    describe "subpath normalization" do
      it "removes empty segments" do
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, nil, "src//main")
        p.subpath.should eq("src/main")
      end

      it "removes dot segments" do
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, nil, "./src/./main")
        p.subpath.should eq("src/main")
      end

      it "removes dot-dot segments" do
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, nil, "src/../lib/main")
        p.subpath.should eq("src/lib/main")
      end

      it "decodes a parsed subpath exactly once" do
        p = Purl::PackageURL.parse("pkg:npm/pkg#foo%252Fbar")
        p.subpath.should eq("foo%2Fbar")
      end

      it "round-trips a subpath segment containing a literal percent sign" do
        original = Purl::PackageURL.new("npm", nil, "pkg", subpath: "100%")
        original.subpath.should eq("100%")
        original.to_s.should eq("pkg:npm/pkg#100%25")
        (Purl::PackageURL.parse(original.to_s) == original).should be_true
      end

      it "round-trips a subpath whose segment contains a literal %2F" do
        p = Purl::PackageURL.parse("pkg:npm/pkg#foo%252Fbar")
        p.to_s.should eq("pkg:npm/pkg#foo%252Fbar")
        (Purl::PackageURL.parse(p.to_s) == p).should be_true
      end

      it "splits an encoded slash in a subpath into separate segments" do
        p = Purl::PackageURL.parse("pkg:npm/pkg#foo%2Fbar")
        p.subpath.should eq("foo/bar")
        p.to_s.should eq("pkg:npm/pkg#foo/bar")
      end

      it "drops whitespace-only subpath segments" do
        p = Purl::PackageURL.parse("pkg:npm/pkg#src/%20/main")
        p.subpath.should eq("src/main")
      end

      it "returns nil for a whitespace-only subpath" do
        Purl::PackageURL.new("npm", nil, "pkg", subpath: "  ").subpath.should be_nil
      end

      it "returns nil for subpath that normalizes to empty" do
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, nil, "././..")
        p.subpath.should be_nil
      end

      it "removes leading and trailing slashes" do
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, nil, "/src/main/")
        p.subpath.should eq("src/main")
      end
    end

    # =========================================================================
    # #to_s
    # =========================================================================
    describe "#to_s" do
      it "returns purl with all components" do
        quals = {"repository_url" => "https://example.com"}
        p = Purl::PackageURL.new("npm", "@angular", "animation", "12.3.1", quals, "src/main")
        p.to_s.should eq("pkg:npm/%40angular/animation@12.3.1?repository_url=https://example.com#src/main")
      end

      it "returns purl without namespace" do
        p = Purl::PackageURL.new("npm", nil, "lodash", "4.17.21")
        p.to_s.should eq("pkg:npm/lodash@4.17.21")
      end

      it "returns purl without version" do
        p = Purl::PackageURL.new("npm", nil, "lodash")
        p.to_s.should eq("pkg:npm/lodash")
      end

      it "returns purl with only type and name" do
        p = Purl::PackageURL.new("pypi", nil, "requests")
        p.to_s.should eq("pkg:pypi/requests")
      end

      it "encodes special characters in namespace" do
        p = Purl::PackageURL.new("npm", "@scope", "pkg", "1.0.0")
        p.to_s.should eq("pkg:npm/%40scope/pkg@1.0.0")
      end

      it "sorts qualifier keys alphabetically" do
        quals = {"z_key" => "z_val", "a_key" => "a_val"}
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, quals)
        p.to_s.should eq("pkg:npm/pkg?a_key=a_val&z_key=z_val")
      end

      it "encodes namespace segments individually" do
        p = Purl::PackageURL.new("maven", "org.apache.commons", "lang3", "3.12.0")
        result = p.to_s
        result.should eq("pkg:maven/org.apache.commons/lang3@3.12.0")
      end

      it "encodes multi-segment namespace with special chars" do
        p = Purl::PackageURL.new("npm", "@scope/sub", "pkg")
        result = p.to_s
        result.should contain("%40scope/sub/pkg")
      end

      it "preserves colon in qualifier values" do
        quals = {"checksum" => "sha256:abc123"}
        p = Purl::PackageURL.new("npm", nil, "pkg", nil, quals)
        p.to_s.should contain("checksum=sha256:abc123")
      end
    end

    # =========================================================================
    # .parse
    # =========================================================================
    describe ".parse" do
      it "parses a purl with all components" do
        p = Purl::PackageURL.parse("pkg:npm/%40angular/animation@12.3.1?repository_url=https://example.com#src/main")
        p.type.should eq("npm")
        p.namespace.should eq("@angular")
        p.name.should eq("animation")
        p.version.should eq("12.3.1")
        p.qualifiers.should eq({"repository_url" => "https://example.com"})
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
        p.qualifiers.should eq({"vcs_url" => "git://github.com/lodash/lodash.git"})
      end

      it "normalizes type to lowercase when parsing" do
        p = Purl::PackageURL.parse("pkg:NPM/lodash@1.0.0")
        p.type.should eq("npm")
      end

      it "normalizes pypi name when parsing" do
        p = Purl::PackageURL.parse("pkg:pypi/My_Package@1.0.0")
        p.name.should eq("my-package")
      end

      it "normalizes npm namespace when parsing" do
        p = Purl::PackageURL.parse("pkg:npm/%40Angular/core@1.0.0")
        p.namespace.should eq("@angular")
      end

      it "parses qualifiers with multiple key-value pairs" do
        p = Purl::PackageURL.parse("pkg:rpm/fedora/curl@7.76.0?arch=x86_64&distro=fedora-34")
        p.qualifiers.should eq({"arch" => "x86_64", "distro" => "fedora-34"})
      end

      it "decodes percent-encoded qualifier values" do
        p = Purl::PackageURL.parse("pkg:npm/pkg?key=hello%20world")
        p.qualifiers.should eq({"key" => "hello world"})
      end

      it "parses subpath with dot segments removed" do
        p = Purl::PackageURL.parse("pkg:npm/pkg#./src/../lib/main")
        p.subpath.should eq("src/lib/main")
      end

      it "handles purl with double-slash after scheme" do
        p = Purl::PackageURL.parse("pkg://npm/lodash@1.0.0")
        p.type.should eq("npm")
        p.name.should eq("lodash")
        p.version.should eq("1.0.0")
      end

      it "raises for invalid purl" do
        expect_raises(Purl::Error) do
          Purl::PackageURL.parse("invalid-purl")
        end
      end

      it "raises for purl without pkg scheme" do
        expect_raises(Purl::Error) do
          Purl::PackageURL.parse("npm:npm/lodash@1.0.0")
        end
      end

      it "raises for empty string" do
        expect_raises(Purl::Error) do
          Purl::PackageURL.parse("")
        end
      end

      it "raises for purl with empty name" do
        expect_raises(Purl::Error) do
          Purl::PackageURL.parse("pkg:npm/")
        end
      end

      it "decodes version percent encoding" do
        p = Purl::PackageURL.parse("pkg:npm/pkg@1.0.0%2Bbuild.123")
        p.version.should eq("1.0.0+build.123")
      end

      it "decodes namespace segments individually" do
        p = Purl::PackageURL.parse("pkg:npm/%40scope/pkg@1.0.0")
        p.namespace.should eq("@scope")
        p.name.should eq("pkg")
      end
    end

    # =========================================================================
    # Equality and hash
    # =========================================================================
    describe "equality" do
      it "considers identical purls equal" do
        a = Purl::PackageURL.new("npm", "@scope", "pkg", "1.0.0")
        b = Purl::PackageURL.new("npm", "@scope", "pkg", "1.0.0")
        (a == b).should be_true
      end

      it "considers purls with different type case equal (both normalized)" do
        a = Purl::PackageURL.new("NPM", nil, "lodash")
        b = Purl::PackageURL.new("npm", nil, "lodash")
        (a == b).should be_true
      end

      it "considers purls with different pypi name forms equal" do
        a = Purl::PackageURL.new("pypi", nil, "My_Package")
        b = Purl::PackageURL.new("pypi", nil, "my-package")
        (a == b).should be_true
      end

      it "considers purls with different versions not equal" do
        a = Purl::PackageURL.new("npm", nil, "lodash", "1.0.0")
        b = Purl::PackageURL.new("npm", nil, "lodash", "2.0.0")
        (a == b).should be_false
      end

      it "considers purls with different qualifiers not equal" do
        a = Purl::PackageURL.new("npm", nil, "pkg", nil, {"key" => "val1"})
        b = Purl::PackageURL.new("npm", nil, "pkg", nil, {"key" => "val2"})
        (a == b).should be_false
      end

      it "can be used as hash keys" do
        a = Purl::PackageURL.new("npm", nil, "lodash", "1.0.0")
        b = Purl::PackageURL.new("NPM", nil, "lodash", "1.0.0")
        set = Set{a}
        set.includes?(b).should be_true
      end

      it "parsed and constructed purls are equal" do
        constructed = Purl::PackageURL.new("npm", "@angular", "animation", "12.3.1")
        parsed = Purl::PackageURL.parse("pkg:npm/%40angular/animation@12.3.1")
        (constructed == parsed).should be_true
      end
    end

    # =========================================================================
    # Roundtrip tests
    # =========================================================================
    describe "roundtrip" do
      it "can parse what it generates" do
        original = Purl::PackageURL.new("gem", nil, "rails", "7.0.0")
        parsed = Purl::PackageURL.parse(original.to_s)
        (parsed == original).should be_true
      end

      it "can parse what it generates with namespace" do
        original = Purl::PackageURL.new("npm", "@rails", "actioncable", "7.0.0")
        parsed = Purl::PackageURL.parse(original.to_s)
        (parsed == original).should be_true
      end

      it "handles version with special characters" do
        original = Purl::PackageURL.new("npm", nil, "package", "1.0.0+build.123")
        purl_str = original.to_s
        purl_str.should contain("%2B") # + should be encoded
        parsed = Purl::PackageURL.parse(purl_str)
        parsed.version.should eq("1.0.0+build.123")
      end

      it "roundtrips with qualifiers" do
        quals = {"arch" => "x86_64", "distro" => "fedora-34"}
        original = Purl::PackageURL.new("rpm", "fedora", "curl", "7.76.0", quals)
        parsed = Purl::PackageURL.parse(original.to_s)
        (parsed == original).should be_true
      end

      it "roundtrips with subpath" do
        original = Purl::PackageURL.new("npm", nil, "pkg", "1.0.0", nil, "src/main")
        parsed = Purl::PackageURL.parse(original.to_s)
        (parsed == original).should be_true
      end

      it "roundtrips maven with all components" do
        quals = {"classifier" => "sources"}
        original = Purl::PackageURL.new("maven", "org.apache.commons", "commons-lang3", "3.12.0", quals)
        parsed = Purl::PackageURL.parse(original.to_s)
        (parsed == original).should be_true
      end

      it "roundtrips golang purl" do
        original = Purl::PackageURL.new("golang", "github.com/gorilla", "mux", "1.8.0")
        parsed = Purl::PackageURL.parse(original.to_s)
        (parsed == original).should be_true
      end

      it "roundtrips pypi purl with normalization" do
        original = Purl::PackageURL.new("pypi", nil, "My_Package", "1.0.0")
        purl_str = original.to_s
        parsed = Purl::PackageURL.parse(purl_str)
        parsed.name.should eq("my-package")
        (parsed == original).should be_true
      end
    end

    # =========================================================================
    # Official spec test cases
    # =========================================================================
    describe "spec compliance" do
      it "handles npm scoped package" do
        p = Purl::PackageURL.parse("pkg:npm/%40angular/animation@12.3.1")
        p.type.should eq("npm")
        p.namespace.should eq("@angular")
        p.name.should eq("animation")
        p.version.should eq("12.3.1")
      end

      it "handles maven package" do
        p = Purl::PackageURL.parse("pkg:maven/org.apache.commons/commons-lang3@3.12.0?classifier=sources")
        p.type.should eq("maven")
        p.namespace.should eq("org.apache.commons")
        p.name.should eq("commons-lang3")
        p.version.should eq("3.12.0")
        p.qualifiers.should eq({"classifier" => "sources"})
      end

      it "handles pypi package with normalization" do
        p = Purl::PackageURL.parse("pkg:pypi/Django_Rest_Framework@3.14.0")
        p.type.should eq("pypi")
        p.name.should eq("django-rest-framework")
        p.version.should eq("3.14.0")
      end

      it "handles golang package" do
        p = Purl::PackageURL.parse("pkg:golang/github.com/gorilla/mux@1.8.0")
        p.type.should eq("golang")
        p.namespace.should eq("github.com/gorilla")
        p.name.should eq("mux")
        p.version.should eq("1.8.0")
      end

      it "handles nuget package" do
        p = Purl::PackageURL.parse("pkg:nuget/Newtonsoft.Json@13.0.1")
        p.type.should eq("nuget")
        p.name.should eq("Newtonsoft.Json")
        p.version.should eq("13.0.1")
      end

      it "handles gem package" do
        p = Purl::PackageURL.parse("pkg:gem/ruby-advisory-db-check@0.12.4")
        p.type.should eq("gem")
        p.name.should eq("ruby-advisory-db-check")
        p.version.should eq("0.12.4")
      end

      it "handles github package" do
        p = Purl::PackageURL.parse("pkg:github/Package-URL/purl-spec@244fd47e07d1004f0aed9c")
        p.type.should eq("github")
        p.namespace.should eq("package-url")
        p.name.should eq("purl-spec")
        p.version.should eq("244fd47e07d1004f0aed9c")
      end

      it "handles docker package" do
        p = Purl::PackageURL.parse("pkg:docker/cassandra@latest")
        p.type.should eq("docker")
        p.name.should eq("cassandra")
        p.version.should eq("latest")
      end

      it "handles rpm package with qualifiers" do
        p = Purl::PackageURL.parse("pkg:rpm/fedora/curl@7.50.3-1.fc25?arch=i386&distro=fedora-25")
        p.type.should eq("rpm")
        p.namespace.should eq("fedora")
        p.name.should eq("curl")
        p.version.should eq("7.50.3-1.fc25")
        p.qualifiers.should eq({"arch" => "i386", "distro" => "fedora-25"})
      end

      it "handles deb package" do
        p = Purl::PackageURL.parse("pkg:deb/debian/curl@7.50.3-1?arch=i386&distro=jessie")
        p.type.should eq("deb")
        p.namespace.should eq("debian")
        p.name.should eq("curl")
        p.version.should eq("7.50.3-1")
        p.qualifiers.should eq({"arch" => "i386", "distro" => "jessie"})
      end

      it "handles bitbucket package" do
        p = Purl::PackageURL.parse("pkg:bitbucket/birKenworfeld/pyPY@244fd47e07d1004")
        p.type.should eq("bitbucket")
        p.namespace.should eq("birkenworfeld")
        p.name.should eq("pypy")
      end

      it "handles cargo package" do
        p = Purl::PackageURL.parse("pkg:cargo/rand@0.7.2")
        p.type.should eq("cargo")
        p.name.should eq("rand")
        p.version.should eq("0.7.2")
      end

      it "handles composer package" do
        p = Purl::PackageURL.parse("pkg:composer/laravel/framework@6.0")
        p.type.should eq("composer")
        p.namespace.should eq("laravel")
        p.name.should eq("framework")
        p.version.should eq("6.0")
      end

      it "handles swift package" do
        p = Purl::PackageURL.parse("pkg:swift/github.com/apple/swift-nio@2.41.0")
        p.type.should eq("swift")
        p.namespace.should eq("github.com/apple")
        p.name.should eq("swift-nio")
        p.version.should eq("2.41.0")
      end

      it "handles cran package" do
        p = Purl::PackageURL.parse("pkg:cran/ggplot2@3.4.0")
        p.type.should eq("cran")
        p.name.should eq("ggplot2")
        p.version.should eq("3.4.0")
      end

      it "handles hackage package" do
        p = Purl::PackageURL.parse("pkg:hackage/aeson@2.1.0.0")
        p.type.should eq("hackage")
        p.name.should eq("aeson")
        p.version.should eq("2.1.0.0")
      end

      it "handles hex package" do
        p = Purl::PackageURL.parse("pkg:hex/phoenix@1.7.0")
        p.type.should eq("hex")
        p.name.should eq("phoenix")
        p.version.should eq("1.7.0")
      end

      it "normalizes composer namespace and name to lowercase when parsing" do
        p = Purl::PackageURL.parse("pkg:composer/Framework/Laravel")
        p.namespace.should eq("framework")
        p.name.should eq("laravel")
        p.to_s.should eq("pkg:composer/framework/laravel")
      end

      it "normalizes pub name when parsing" do
        p = Purl::PackageURL.parse("pkg:pub/Flutter_Lints")
        p.name.should eq("flutter_lints")
      end

      it "lowercases huggingface version when parsing" do
        p = Purl::PackageURL.parse("pkg:huggingface/microsoft/deberta@MAIN-ABC123")
        p.version.should eq("main-abc123")
      end
    end

    # =========================================================================
    # %2F preservation in segments (security: SBOM matching collisions)
    # =========================================================================
    describe "%2F preservation" do
      # Type-specific normalization must not reach into the marker itself.
      it "keeps the %2F marker canonical when the type lowercases names" do
        p = Purl::PackageURL.parse("pkg:npm/Foo%2FBar")
        p.name.should eq("foo%2Fbar")
        p.to_s.should eq("pkg:npm/foo%2Fbar")
      end

      it "keeps the %2F marker canonical when the type lowercases namespaces" do
        p = Purl::PackageURL.parse("pkg:npm/A%2FB/c")
        p.namespace.should eq("a%2Fb")
        p.to_s.should eq("pkg:npm/a%2Fb/c")
      end

      it "does not let pub name normalization rewrite the %2F marker" do
        p = Purl::PackageURL.parse("pkg:pub/Foo%2FBar")
        p.name.should eq("foo%2Fbar")
        p.to_s.should eq("pkg:pub/foo%2Fbar")
      end

      it "does not let pypi name normalization rewrite the %2F marker" do
        p = Purl::PackageURL.parse("pkg:pypi/Foo_A%2FBar_B")
        p.name.should eq("foo-a%2Fbar-b")
      end

      it "still distinguishes an encoded slash from a real one after normalization" do
        Purl::PackageURL.parse("pkg:pub/foo%2Fbar")
          .should_not eq(Purl::PackageURL.parse("pkg:pub/foo/bar"))
      end

      it "preserves %2F inside a namespace segment so it is not conflated with the path separator" do
        a = Purl::PackageURL.parse("pkg:generic/foo%2Fbar/baz")
        b = Purl::PackageURL.parse("pkg:generic/foo/bar/baz")
        a.should_not eq(b)
        a.to_s.should eq("pkg:generic/foo%2Fbar/baz")
        b.to_s.should eq("pkg:generic/foo/bar/baz")
      end

      it "preserves %2F inside a name segment" do
        p = Purl::PackageURL.parse("pkg:generic/foo%2Fbar")
        p.namespace.should be_nil
        p.name.should eq("foo%2Fbar")
        p.to_s.should eq("pkg:generic/foo%2Fbar")
      end

      it "still decodes other percent-escapes (e.g. %40)" do
        p = Purl::PackageURL.parse("pkg:npm/%40angular/animation@12.3.1")
        p.namespace.should eq("@angular")
      end

      it "round-trips %2F together with other encoded characters" do
        p = Purl::PackageURL.parse("pkg:generic/a%40b%2Fc/d")
        p.namespace.should eq("a@b%2Fc")
        p.to_s.should eq("pkg:generic/a%40b%2Fc/d")
      end

      # Regression: a percent-encoded control character (e.g. %01) decodes to a
      # byte that previously matched the U+0001 sentinel used to protect %2F,
      # which made an encoded control char collide with an encoded slash.
      it "does not let a percent-encoded control char collide with %2F at the encoder level" do
        Purl::Encoder.decode_segment("foo%01bar").should_not eq(Purl::Encoder.decode_segment("foo%2Fbar"))
      end

      it "parses an encoded control char and an encoded slash to distinct namespaces" do
        a = Purl::PackageURL.parse("pkg:generic/foo%01bar/name")
        b = Purl::PackageURL.parse("pkg:generic/foo%2Fbar/name")
        a.namespace.should_not eq(b.namespace)
        b.namespace.should eq("foo%2Fbar")
      end
    end

    # =========================================================================
    # Subpath traversal hardening
    # =========================================================================
    describe "subpath traversal" do
      it "strips traversal segments hidden behind percent-encoded slash" do
        p = Purl::PackageURL.parse("pkg:generic/x#foo/%2E%2E%2Fbar")
        # Decoded segment "../bar" is split into ["..", "bar"]; the leading
        # ".." is filtered, leaving "foo/bar".
        p.subpath.should eq("foo/bar")
      end

      it "strips traversal segments passed via the constructor" do
        p = Purl::PackageURL.new("generic", nil, "x", subpath: "%2E%2E/bar")
        p.subpath.should eq("bar")
      end

      it "strips fully-percent-encoded traversal" do
        p = Purl::PackageURL.parse("pkg:generic/x#%2E%2E/secret")
        p.subpath.should eq("secret")
      end
    end

    # =========================================================================
    # Qualifier key validation in the parser
    # =========================================================================
    describe "qualifier key validation" do
      it "rejects percent-encoded qualifier keys" do
        expect_raises(Purl::Error, /Invalid qualifier key/) do
          Purl::PackageURL.parse("pkg:generic/x?%41rch=amd64")
        end
      end

      it "rejects qualifier keys with invalid characters" do
        expect_raises(Purl::Error, /Invalid qualifier key/) do
          Purl::PackageURL.parse("pkg:generic/x?ar ch=amd64")
        end
      end
    end
  end
end
