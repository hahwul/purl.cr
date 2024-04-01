require "./spec_helper"

describe Purl do
  # TODO: Write tests

  it "works" do
    true.should eq(true)
  end

  it "should have a version" do
    Purl::VERSION.should_not be_nil
  end

  it "to_s" do
    p = Purl::PackageURL.new("type", "namespace", "name", "version", "qualifiers", "subpath")
    p.to_s.should eq("type:namespace/name@version?qualifiers#subpath")
  end

  it "parse a URL" do
    p = Purl::PackageURL.parse("scheme:type/namespace/name@version?qualifiers#subpath")
    puts p
  end
end
