enum YamlMocks {
  static let yamlContent: String = """
    version: 1
    sourceConfigurations:
      op:
        vault: personal
      fake-source:
        url: https://macpaw.com
    secrets:
      TEST_MPCT_SECRET1_OP_ONLY:
        sources:
          # Test: Should not call OnePassword provider
          op:
            item: "[TEST] mpct.import-secrets.shared-item"
            label: item1-secret
      TEST_MPCT_SECRET2_MULTILINE:
        sources:
          # Test: Must get value from FakeProvider first and not call OnePassword
          fake-source:
            path: /test/mpct/item1/multiline
            key: key
          op:
            item: '[TEST] mpct.import-secrets.shared-item'
            label: item1-multiline
      TEST_MPCT_SECRET3_OP_AND_FAKE:
        sources:
          # Test: Must get value from OnePassword provider first and not call FakeProvider
          op:
            item: '[TEST] mpct.import-secrets.database-item'
            label: item2-secret
          fake-source:
            path: /test/mpct/item2/secret
            key: key
      TEST_MPCT_SECRET4_FAKE_ONLY:
        sources:
          # Test: Should not call OnePassword provider
          fake-source:
            path: /test/mpct/item4/secret
            key: key
      TEST_MPCT_SECRET5_OP_MISSING_FAKE_EXISTS:
        sources:
          # Test: Must get value from OnePassword provider first (but there is no such item)  and then call FakeProvider
          op:
            item: '[TEST] mpct.import-secrets.non-existent-item'
            label: item5-secret
          fake-source:
            path: /test/mpct/item5/secret
            key: key
      TEST_MPCT_SECRET6_OP_MISSING_FAKE_MISSING:
        sources:
          # Test: Must get value from OnePassword provider first (but there is no such item)  and then call FakeProvider and fail
          op:
            item: '[TEST] mpct.import-secrets.non-existent-item'
            label: item6-secret
          fake-source:
            path: /test/mpct/item6/secret
            key: missing
    """
}
