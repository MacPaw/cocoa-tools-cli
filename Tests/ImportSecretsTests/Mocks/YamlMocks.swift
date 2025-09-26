enum YamlMocks {
  static let yamlContent: String = """
    version: 1
    sourceConfigurations:
      op:
        vault: personal
      fake-source:
        url: https://macpaw.com
      vault:
        vaultAddress: https://macpaw.com
        apiVersion: v1
        authenticationMethod: token
        authenticationCredentials:
          token: token
        engines:
          keyValue:
            defaultSecretMountPath: secret
          aws:
            defaultEnginePath: aws
    secrets:
      - prefix: TEST_MPCT_SECRET1_OP_ONLY_
        sources:
          # Test: Should not call FakeProvider provider
          op:
            item: "[TEST] mpct.import-secrets.shared-item"
            labels: 
              - item1-secret
      - prefix: TEST_MPCT_SECRET2_MULTILINE_
        sources:
          # Test: Must get value from FakeProvider first and not call OnePassword
          fake-source:
            path: /test/mpct/item1/multiline
            keys: 
              - item1-multiline
          op:
            item: '[TEST] mpct.import-secrets.shared-item'
            labels: 
              - item1-multiline
      - prefix: TEST_MPCT_SECRET3_OP_AND_FAKE_
        sources:
          # Test: Must get value from OnePassword provider first and not call FakeProvider
          op:
            item: '[TEST] mpct.import-secrets.database-item'
            labels: 
              - item2-secret
          fake-source:
            path: /test/mpct/item2/secret
            keys: 
              - item2-secret
      - prefix: TEST_MPCT_SECRET4_FAKE_ONLY_
        sources:
          # Test: Should not call OnePassword provider
          fake-source:
            path: /test/mpct/item4/secret
            keys: 
              - key
      - prefix: TEST_MPCT_SECRET5_OP_MISSING_FAKE_EXISTS_
        sources:
          # Test: Must get value from OnePassword provider first (but there is no such item)  and then call FakeProvider
          op:
            item: '[TEST] mpct.import-secrets.non-existent-item'
            labels: 
              - item5-secret
          fake-source:
            path: /test/mpct/item5/secret
            keys:
              - item5-secret
      - prefix: TEST_MPCT_SECRET6_OP_MISSING_FAKE_MISSING_
        sources:
          # Test: Must get value from OnePassword provider first (but there is no such item)  and then call FakeProvider and fail
          op:
            item: '[TEST] mpct.import-secrets.non-existent-item'
            labels: 
              - item6-secret
          fake-source:
            path: /test/mpct/item6/secret
            keys: 
              - missing
      - prefix: TEST_MPCT_SECRET7_VAULT_KV_
        sources:
          vault:
            keyValue:
              path: path/secret7
              keys: 
                - key
      - prefix: TEST_MPCT_SECRET7_VAULT_AWS_
        sources:
          vault:
            aws:
              role: role1
              keys: 
                - key1
      - prefix: TEST_MPCT_SECRET8_VAULT_AWS_
        sources:
          vault:
            aws:
              role: role1
              keys:
                - key2
    secretNamesMapping:
      TEST_MPCT_SECRET1_OP_ONLY_item1-secret: TEST_MPCT_SECRET1_OP_ONLY_ITEM1_SECRET
      TEST_MPCT_SECRET2_MULTILINE_item1-multiline: TEST_MPCT_SECRET2_MULTILINE_ITEM1_MULTILINE
      TEST_MPCT_SECRET3_OP_AND_FAKE_item2-secret: TEST_MPCT_SECRET3_OP_AND_FAKE_ITEM2_SECRET
    """
}
