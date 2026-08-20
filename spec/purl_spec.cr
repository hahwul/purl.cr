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

      it "rejects a type with a plus sign" do
        # ECMA-427 limits the type to "ASCII letters and numbers, period '.',
        # and dash '-'"; '+' is not among them.
        expect_raises(Purl::Error, /Invalid type/) do
          Purl::PackageURL.new("c++", nil, "pkg")
        end
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

      it "preserves npm name case" do
        # The npm type definition declares the name case sensitive: mixed-case
        # packages published before 2015 were grandfathered in and lowercasing
        # them would name a different (non-existent) package.
        p = Purl::PackageURL.new("npm", nil, "MyPackage")
        p.name.should eq("MyPackage")
      end

      # Types whose definition declares the name case-insensitive. Each is
      # paired with a namespace its type definition accepts.
      {"hex" => {nil, "Jason"}, "apk" => {"Alpine", "Curl"},
       "alpm" => {"Arch", "PacMan"}, "bitnami" => {nil, "WordPress"},
       "luarocks" => {nil, "LUA-resty-http"}, "brew" => {nil, "SQLite"},
       "otp" => {nil, "Cowboy"}}.each do |type, (ns, raw)|
        it "normalizes #{type} name to lowercase" do
          Purl::PackageURL.new(type, ns, raw).name.should eq(raw.downcase)
        end
      end

      it "represents a raw slash in a name as the %2F marker" do
        p = Purl::PackageURL.new("generic", nil, "foo/bar")
        p.name.should eq("foo%2Fbar")
        p.to_s.should eq("pkg:generic/foo%2Fbar")
      end

      it "makes a constructed name with a slash equal to its parsed form" do
        original = Purl::PackageURL.new("generic", nil, "foo/bar")
        original.should eq(Purl::PackageURL.parse("pkg:generic/foo%2Fbar"))
        (Purl::PackageURL.parse(original.to_s) == original).should be_true
      end

      it "applies type normalization around a slash in a name" do
        Purl::PackageURL.new("pypi", nil, "My_A/My_B").name.should eq("my-a%2Fmy-b")
      end

      it "preserves cpan distribution name case" do
        p = Purl::PackageURL.new("cpan", "DROLSKY", "DateTime")
        p.name.should eq("DateTime")
      end

      it "lowercases a brew tap namespace and formula name" do
        p = Purl::PackageURL.parse("pkg:brew/Homebrew/Core/SQLite@3.43.2")
        p.namespace.should eq("homebrew/core")
        p.name.should eq("sqlite")
      end

      it "lowercases a vscode-extension publisher and name" do
        p = Purl::PackageURL.parse("pkg:vscode-extension/RedHat/Java@1.0.0")
        p.namespace.should eq("redhat")
        p.name.should eq("java")
      end

      # The mlflow definition ties the name's case to the tracking server:
      # Databricks is case-insensitive, Azure ML is case-sensitive.
      it "lowercases an mlflow name tracked on Databricks" do
        p = Purl::PackageURL.parse(
          "pkg:mlflow/CreditFraud@3?repository_url=https://adb-5245952564735461.0.azuredatabricks.net/api/2.0/mlflow")
        p.name.should eq("creditfraud")
      end

      it "preserves an mlflow name tracked on Azure ML" do
        p = Purl::PackageURL.parse(
          "pkg:mlflow/CreditFraud@3?repository_url=https://westus2.api.azureml.ms/mlflow/v1.0")
        p.name.should eq("CreditFraud")
      end

      it "preserves an mlflow name when no repository_url says otherwise" do
        Purl::PackageURL.new("mlflow", nil, "CreditFraud").name.should eq("CreditFraud")
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
      it "preserves npm namespace case" do
        # The npm scope is case sensitive per the npm type definition.
        p = Purl::PackageURL.new("npm", "@Angular", "core")
        p.namespace.should eq("@Angular")
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
       "luarocks" => "Kong", "qpkg" => "Blackberry", "brew" => "Homebrew",
       "yocto" => "Core"}.each do |type, raw|
        it "normalizes #{type} namespace to lowercase" do
          Purl::PackageURL.new(type, raw, "pkg").namespace.should eq(raw.downcase)
        end
      end

      it "uppercases the cpan namespace (CPANID)" do
        p = Purl::PackageURL.new("cpan", "drolsky", "DateTime")
        p.namespace.should eq("DROLSKY")
        p.to_s.should eq("pkg:cpan/DROLSKY/DateTime")
      end

      it "drops blank namespace segments" do
        p = Purl::PackageURL.new("generic", "a/ /b", "pkg")
        p.namespace.should eq("a/b")
      end

      it "collapses a namespace of only whitespace to nil" do
        p = Purl::PackageURL.new("generic", " / ", "pkg")
        p.namespace.should be_nil
        p.to_s.should eq("pkg:generic/pkg")
      end

      it "round-trips a namespace that contains a blank segment" do
        original = Purl::PackageURL.new("generic", " /a", "pkg")
        (Purl::PackageURL.parse(original.to_s) == original).should be_true
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

      # Types whose definition declares the version case-insensitive.
      it "lowercases pypi version" do
        p = Purl::PackageURL.new("pypi", nil, "django", "1.11.1.DEV1")
        p.version.should eq("1.11.1.dev1")
      end

      it "lowercases vscode-extension version" do
        p = Purl::PackageURL.new("vscode-extension", "redhat", "java", "1.46.2025091308-RC")
        p.version.should eq("1.46.2025091308-rc")
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

      # An unencoded slash after the `@` is malformed input: the slash binds
      # as a path separator, so the `@` is not a version separator at all.
      it "does not read a version across a path separator" do
        p = Purl::PackageURL.parse("pkg:npm/pkg@1/2")
        p.version.should be_nil
        p.namespace.should eq("pkg@1")
        p.name.should eq("2")
      end

      it "round-trips a version containing a literal percent sign" do
        original = Purl::PackageURL.new("generic", nil, "pkg", "100%")
        original.to_s.should eq("pkg:generic/pkg@100%25")
        (Purl::PackageURL.parse(original.to_s) == original).should be_true
      end

      it "round-trips a version whose text contains a literal %2F" do
        original = Purl::PackageURL.new("generic", nil, "pkg", "a%2Fb")
        original.version.should eq("a%2Fb")
        original.to_s.should eq("pkg:generic/pkg@a%252Fb")
        (Purl::PackageURL.parse(original.to_s) == original).should be_true
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
      # ECMA-427: "Each key shall be unique among all the keys of the
      # qualifiers component."
      it "rejects a duplicate qualifier key when parsing" do
        expect_raises(Purl::Error, /Duplicate qualifier key 'arch'/) do
          Purl::PackageURL.parse("pkg:deb/debian/curl@1?arch=amd64&arch=i386")
        end
      end

      it "rejects keys that collide only after downcasing" do
        expect_raises(Purl::Error, /Duplicate qualifier key 'arch'/) do
          Purl::PackageURL.new("npm", nil, "pkg", nil, {"Arch" => "amd64", "arch" => "i386"})
        end
      end

      it "does not treat a skipped empty value as a duplicate" do
        p = Purl::PackageURL.parse("pkg:npm/pkg?arch=&arch=x86")
        p.qualifiers.should eq({"arch" => "x86"})
      end

      it "does not expose its internal qualifier hash" do
        p = Purl::PackageURL.parse("pkg:npm/pkg?arch=x86")
        p.qualifiers.not_nil!["arch"] = "tampered"
        p.qualifiers.should eq({"arch" => "x86"})
        p.to_s.should eq("pkg:npm/pkg?arch=x86")
      end

      it "keeps equality and hash stable when a returned qualifier hash is mutated" do
        key = Purl::PackageURL.parse("pkg:npm/pkg?arch=x86")
        lookup = {key => :found}
        key.qualifiers.not_nil!["arch"] = "tampered"
        lookup[key]?.should eq(:found)
        key.should eq(Purl::PackageURL.parse("pkg:npm/pkg?arch=x86"))
      end

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
        p.to_s.should eq("pkg:npm/%40angular/animation@12.3.1?repository_url=https:%2F%2Fexample.com#src/main")
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
      # The version separator can only live in the last path segment, so an
      # unencoded npm scope is a namespace rather than a version marker.
      it "parses an unencoded npm scope as a namespace" do
        p = Purl::PackageURL.parse("pkg:npm/@babel/core")
        p.namespace.should eq("@babel")
        p.name.should eq("core")
        p.version.should be_nil
        p.to_s.should eq("pkg:npm/%40babel/core")
      end

      it "parses an unencoded npm scope alongside a version" do
        p = Purl::PackageURL.parse("pkg:npm/@babel/core@7.20.0")
        p.namespace.should eq("@babel")
        p.name.should eq("core")
        p.version.should eq("7.20.0")
      end

      it "still rejects a purl whose only segment is a version" do
        expect_raises(Purl::Error, /name must not be empty/) do
          Purl::PackageURL.parse("pkg:cran/@0.9.1")
        end
      end

      it "still rejects a trailing empty name before a version" do
        expect_raises(Purl::Error, /name must not be empty/) do
          Purl::PackageURL.parse("pkg:swift/github.com/Alamofire/@5.4.3")
        end
      end

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

      it "preserves npm namespace case when parsing" do
        p = Purl::PackageURL.parse("pkg:npm/%40Angular/core@1.0.0")
        p.namespace.should eq("@Angular")
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
    # =========================================================================
    # Percent-encoding rules (ECMA-427 clause 5.4)
    # =========================================================================
    describe "percent-encoding" do
      # "the colon ':' ... shall not be percent-encoded, whether used as a
      # Separator Character or otherwise"
      it "never encodes a colon in the version" do
        Purl::PackageURL.new("oci", nil, "debian", "sha256:244fd47e07d10")
          .to_s.should eq("pkg:oci/debian@sha256:244fd47e07d10")
      end

      it "never encodes a colon in a deb epoch version" do
        Purl::PackageURL.new("deb", "debian", "attr", "1:2.4.47-2")
          .to_s.should eq("pkg:deb/debian/attr@1:2.4.47-2")
      end

      it "never encodes a colon in a name or subpath" do
        p = Purl::PackageURL.new("generic", "a:b", "c:d", nil, nil, "e:f")
        p.to_s.should eq("pkg:generic/a:b/c:d#e:f")
      end

      it "keeps the colon but encodes the slashes in a qualifier value" do
        p = Purl::PackageURL.new("hex", nil, "bar", "1.2.3",
          {"repository_url" => "https://myrepo.example.com"})
        p.to_s.should eq("pkg:hex/bar@1.2.3?repository_url=https:%2F%2Fmyrepo.example.com")
      end

      it "round-trips a qualifier value containing slashes" do
        original = Purl::PackageURL.new("oci", nil, "debian", nil,
          {"repository_url" => "docker.io/library/debian"})
        (Purl::PackageURL.parse(original.to_s) == original).should be_true
      end

      it "still encodes other reserved characters" do
        Purl::PackageURL.new("npm", nil, "pkg", "1.0.0+build")
          .to_s.should eq("pkg:npm/pkg@1.0.0%2Bbuild")
      end
    end

    describe "%2F preservation" do
      # Type-specific normalization must not reach into the marker itself.
      it "keeps the %2F marker canonical when the type lowercases names" do
        p = Purl::PackageURL.parse("pkg:hex/Foo%2FBar")
        p.name.should eq("foo%2Fbar")
        p.to_s.should eq("pkg:hex/foo%2Fbar")
      end

      it "keeps the %2F marker canonical when the type lowercases namespaces" do
        p = Purl::PackageURL.parse("pkg:hex/A%2FB/c")
        p.namespace.should eq("a%2Fb")
        p.to_s.should eq("pkg:hex/a%2Fb/c")
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
        Purl::PackageURL.parse("pkg:hex/foo%2Fbar")
          .should_not eq(Purl::PackageURL.parse("pkg:hex/foo/bar"))
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

      # ECMA-427: "The key shall be composed only of lowercase ASCII letters
      # and numbers, period '.', dash '-' and underscore '_'." A purl whose
      # key is not already lowercase is invalid, so it is rejected rather
      # than silently repaired.
      it "rejects a qualifier key that is not lowercase" do
        expect_raises(Purl::Error, /Invalid qualifier key 'Platform'/) do
          Purl::PackageURL.parse("pkg:gem/jruby-launcher@1.1.2?Platform=java")
        end
      end

      it "rejects a qualifier key with an interior uppercase letter" do
        expect_raises(Purl::Error, /Invalid qualifier key/) do
          Purl::PackageURL.parse("pkg:generic/x?repositorY_url=example.com")
        end
      end

      # The build algorithm joins "the lowercased key" with its value, so the
      # constructor still normalizes a caller-supplied key.
      it "lowercases a constructed qualifier key" do
        p = Purl::PackageURL.new("gem", nil, "jruby-launcher", "1.1.2", {"Platform" => "java"})
        p.to_s.should eq("pkg:gem/jruby-launcher@1.1.2?platform=java")
      end
    end

    # =========================================================================
    # Per-type component rules (purl type definitions)
    # =========================================================================
    describe "type rules" do
      it "requires a namespace for a type whose definition demands one" do
        expect_raises(Purl::Error, /type 'swift' requires a namespace/) do
          Purl::PackageURL.parse("pkg:swift/some-package@1.0.0")
        end
      end

      it "requires a namespace when building such a type" do
        expect_raises(Purl::Error, /type 'vscode-extension' requires a namespace/) do
          Purl::PackageURL.new("vscode-extension", nil, "java", "1.46.0")
        end
      end

      it "rejects a namespace for a type whose definition prohibits one" do
        expect_raises(Purl::Error, /type 'vcpkg' does not allow a namespace/) do
          Purl::PackageURL.parse("pkg:vcpkg/boost/asio@1.84.0")
        end
      end

      it "rejects a namespace when building a type that prohibits one" do
        expect_raises(Purl::Error, /type 'otp' does not allow a namespace/) do
          Purl::PackageURL.new("otp", "namespace", "hex", "2.1.1")
        end
      end

      it "enforces the permitted characters of a name" do
        expect_raises(Purl::Error, /Invalid name 'dogs' for type 'chrome-extension'/) do
          Purl::PackageURL.parse("pkg:chrome-extension/dogs")
        end
      end

      it "enforces the permitted characters of a version" do
        expect_raises(Purl::Error, /Invalid version '1.2.3-beta'/) do
          Purl::PackageURL.parse("pkg:chrome-extension/dlpngalgnefjeiefhmpklpfiohadpglk@1.2.3-beta")
        end
      end

      it "accepts a name and version that match the permitted characters" do
        p = Purl::PackageURL.parse("pkg:chrome-extension/dlpngalgnefjeiefhmpklpfiohadpglk@1.2.3")
        p.name.should eq("dlpngalgnefjeiefhmpklpfiohadpglk")
        p.version.should eq("1.2.3")
      end

      it "requires the qualifiers a definition marks required" do
        expect_raises(Purl::Error, /type 'julia' requires the 'uuid' qualifier/) do
          Purl::PackageURL.parse("pkg:julia/Dates")
        end
      end

      it "accepts a purl that carries its required qualifier" do
        p = Purl::PackageURL.parse("pkg:julia/Dates?uuid=ade2ca70-3891-5945-98fb-dc099432e06a")
        p.name.should eq("Dates")
      end

      it "rejects a cpan module name in place of a distribution name" do
        expect_raises(Purl::Error, /must not contain '::'/) do
          Purl::PackageURL.parse("pkg:cpan/URI::PackageURL")
        end
      end

      it "accepts a cpan distribution name" do
        Purl::PackageURL.parse("pkg:cpan/GDT/URI-PackageURL").name.should eq("URI-PackageURL")
      end
    end

    # =========================================================================
    # Repository-path names (git)
    # =========================================================================
    describe "slashed names" do
      it "splits a git purl into a host namespace and a repository path name" do
        p = Purl::PackageURL.parse("pkg:git/codeberg.org/forgejo/forgejo@a72d2c07")
        p.namespace.should eq("codeberg.org")
        p.name.should eq("forgejo/forgejo")
        p.version.should eq("a72d2c07")
      end

      it "serializes a git repository path with unencoded slashes" do
        p = Purl::PackageURL.new("git", "codeberg.org", "forgejo/forgejo", "a72d2c07")
        p.to_s.should eq("pkg:git/codeberg.org/forgejo/forgejo@a72d2c07")
      end

      it "round-trips a git purl carrying a subpath" do
        input = "pkg:git/codeberg.org/forgejo/forgejo@a72d2c07#options/locale_readme.md"
        p = Purl::PackageURL.parse(input)
        p.subpath.should eq("options/locale_readme.md")
        p.to_s.should eq(input)
      end

      it "preserves git namespace and name case" do
        # git-definition.json declares both case_sensitive.
        p = Purl::PackageURL.parse("pkg:git/GitLab.com/GNOME/adwaita-fonts")
        p.namespace.should eq("GitLab.com")
        p.name.should eq("GNOME/adwaita-fonts")
      end

      it "rejects a multi-segment git namespace, which cannot round-trip" do
        expect_raises(Purl::Error, /must be a single segment/) do
          Purl::PackageURL.new("git", "codeberg.org/forgejo", "forgejo")
        end
      end
    end
  end
end
