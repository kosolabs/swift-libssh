# Changelog

## [1.23.0](https://github.com/kosolabs/swift-libssh/compare/v1.22.4...v1.23.0) (2026-09-01)


### Features

* distinguish closed handles from connection failures ([#186](https://github.com/kosolabs/swift-libssh/issues/186)) ([5930e89](https://github.com/kosolabs/swift-libssh/commit/5930e89ee1c23a7e963f8181a8d9dfc181b0e646))


### Bug Fixes

* use-after-free when closing an sftp client with open handles ([#184](https://github.com/kosolabs/swift-libssh/issues/184)) ([995feff](https://github.com/kosolabs/swift-libssh/commit/995feffdb9535a4e163121ecfd5ea69a840c5ce2))

## [1.22.4](https://github.com/kosolabs/swift-libssh/compare/v1.22.3...v1.22.4) (2026-08-28)


### Bug Fixes

* report use of a closed session as a connection failure ([#182](https://github.com/kosolabs/swift-libssh/issues/182)) ([b88a7b7](https://github.com/kosolabs/swift-libssh/commit/b88a7b7797cb211c98057c273dd007808dfd6635))

## [1.22.3](https://github.com/kosolabs/swift-libssh/compare/v1.22.2...v1.22.3) (2026-08-28)


### Bug Fixes

* use-after-free when sftp handles outlive a closed session ([#180](https://github.com/kosolabs/swift-libssh/issues/180)) ([0a481ee](https://github.com/kosolabs/swift-libssh/commit/0a481ee3e811d3db28555063ea18b40d1c5be693))

## [1.22.2](https://github.com/kosolabs/swift-libssh/compare/v1.22.1...v1.22.2) (2026-08-28)


### Bug Fixes

* creating an existing symlink throws file already exists ([#178](https://github.com/kosolabs/swift-libssh/issues/178)) ([5165700](https://github.com/kosolabs/swift-libssh/commit/5165700c49fa5fc588784601993a1448d4554bae))

## [1.22.1](https://github.com/kosolabs/swift-libssh/compare/v1.22.0...v1.22.1) (2026-08-27)


### Bug Fixes

* error handling when all channels have been exhausted ([#174](https://github.com/kosolabs/swift-libssh/issues/174)) ([2937469](https://github.com/kosolabs/swift-libssh/commit/2937469fbc4f851b9f0b34fd044e7aac09f98c83))
* various leaks caused by failed init ([#176](https://github.com/kosolabs/swift-libssh/issues/176)) ([7b7552c](https://github.com/kosolabs/swift-libssh/commit/7b7552c78b16e696da3fe860cd8a589d13712207))

## [1.22.0](https://github.com/kosolabs/swift-libssh/compare/v1.21.2...v1.22.0) (2026-08-26)


### Features

* add concurrent transfer stress test CLI command ([#166](https://github.com/kosolabs/swift-libssh/issues/166)) ([f353f3a](https://github.com/kosolabs/swift-libssh/commit/f353f3ad44cb8fc8d0a6c023915d6664c177d0d4))
* add timeout argument to stress test ([212ea3b](https://github.com/kosolabs/swift-libssh/commit/212ea3b5fbcbd89f53d90bf94636b0e0a7f8e7f5))


### Bug Fixes

* deadlock caused by concurrent uploads and downloads ([#169](https://github.com/kosolabs/swift-libssh/issues/169)) ([c97bd41](https://github.com/kosolabs/swift-libssh/commit/c97bd41b72e765b14e228ab9db4e94ecb2423505))
* write of large sliced data ([#168](https://github.com/kosolabs/swift-libssh/issues/168)) ([79b8c37](https://github.com/kosolabs/swift-libssh/commit/79b8c37a1144bab80d8dbc092b1c1f3f352eeb18))

## [1.21.2](https://github.com/kosolabs/swift-libssh/compare/v1.21.1...v1.21.2) (2026-08-24)


### Bug Fixes

* align default SFTP modes with OpenSSH standards ([#164](https://github.com/kosolabs/swift-libssh/issues/164)) ([86fe642](https://github.com/kosolabs/swift-libssh/commit/86fe642edc17753666f347dbb72cc22cec10f65a))

## [1.21.1](https://github.com/kosolabs/swift-libssh/compare/v1.21.0...v1.21.1) (2026-08-20)


### Bug Fixes

* adopt standard naming conventions ([#162](https://github.com/kosolabs/swift-libssh/issues/162)) ([bc8737e](https://github.com/kosolabs/swift-libssh/commit/bc8737e3edc441512e8e062b23f14e3535895315))

## [1.21.0](https://github.com/kosolabs/swift-libssh/compare/v1.20.1...v1.21.0) (2026-08-18)


### Features

* import and validate private keys without a session ([#160](https://github.com/kosolabs/swift-libssh/issues/160)) ([e78414c](https://github.com/kosolabs/swift-libssh/commit/e78414c32bd9e4b18f2a04cc5da5eedf677dee2b))

## [1.20.1](https://github.com/kosolabs/swift-libssh/compare/v1.20.0...v1.20.1) (2026-08-05)


### Bug Fixes

* renovate should update deps with 'fix' so that a release is triggered ([#156](https://github.com/kosolabs/swift-libssh/issues/156)) ([56b6d00](https://github.com/kosolabs/swift-libssh/commit/56b6d0072459fadd4816a986ce2840ddf93ee437))

## [1.20.0](https://github.com/kosolabs/swift-libssh/compare/v1.19.0...v1.20.0) (2026-07-24)


### Features

* simplify connect and withAuthenticatedClient to use SSHAuthMethod enum ([#142](https://github.com/kosolabs/swift-libssh/issues/142)) ([bc66cf2](https://github.com/kosolabs/swift-libssh/commit/bc66cf23f9c509dc3822e83d757530dec3c199ab))

## [1.19.0](https://github.com/kosolabs/swift-libssh/compare/v1.18.0...v1.19.0) (2026-06-10)


### Features

* narrow thrown error types to SSHError where possible ([#136](https://github.com/kosolabs/swift-libssh/issues/136)) ([d7c066e](https://github.com/kosolabs/swift-libssh/commit/d7c066e705a38be28687a082293ea8da22209aae))

## [1.18.0](https://github.com/kosolabs/swift-libssh/compare/v1.17.3...v1.18.0) (2026-05-26)


### Features

* helper function to create directories recursively ([#134](https://github.com/kosolabs/swift-libssh/issues/134)) ([57862b5](https://github.com/kosolabs/swift-libssh/commit/57862b5ff2188c2bbaa52cfdfbb09a20f8dd9b13))

## [1.17.3](https://github.com/kosolabs/swift-libssh/compare/v1.17.2...v1.17.3) (2026-05-19)


### Bug Fixes

* use flags to set SFTPAttributes optionally ([#131](https://github.com/kosolabs/swift-libssh/issues/131)) ([1c60b86](https://github.com/kosolabs/swift-libssh/commit/1c60b86c0163ab6486bbf319d216bb874d1e8cef))

## [1.17.2](https://github.com/kosolabs/swift-libssh/compare/v1.17.1...v1.17.2) (2026-05-14)


### Bug Fixes

* local testing failing against docker test server ([#129](https://github.com/kosolabs/swift-libssh/issues/129)) ([7315baf](https://github.com/kosolabs/swift-libssh/commit/7315baf967118a9977a0796640d0a57d402df955))

## [1.17.1](https://github.com/kosolabs/swift-libssh/compare/v1.17.0...v1.17.1) (2026-05-14)


### Bug Fixes

* drop `Path` suffix in parameter names ([#127](https://github.com/kosolabs/swift-libssh/issues/127)) ([b89d6e4](https://github.com/kosolabs/swift-libssh/commit/b89d6e401b2a24ee1fb24a9afc96045d2b066feb))

## [1.17.0](https://github.com/kosolabs/swift-libssh/compare/v1.16.3...v1.17.0) (2026-05-12)


### Features

* add support for symlinks ([#125](https://github.com/kosolabs/swift-libssh/issues/125)) ([b7660ce](https://github.com/kosolabs/swift-libssh/commit/b7660ce61c797fd74417296416589f37b79583ac))

## [1.16.3](https://github.com/kosolabs/swift-libssh/compare/v1.16.2...v1.16.3) (2026-05-07)


### Bug Fixes

* throw .authenticationFailed if we fail to load base64 encoded pk ([#122](https://github.com/kosolabs/swift-libssh/issues/122)) ([c02791a](https://github.com/kosolabs/swift-libssh/commit/c02791aa217b118cd867ca87d40349262f4b1f59))

## [1.16.2](https://github.com/kosolabs/swift-libssh/compare/v1.16.1...v1.16.2) (2026-05-07)


### Bug Fixes

* throw .authenticationFailed if we fail to import the private key ([#120](https://github.com/kosolabs/swift-libssh/issues/120)) ([6dc393c](https://github.com/kosolabs/swift-libssh/commit/6dc393cf5f736cd874c98fb89ff2fad39ffa7673))

## [1.16.1](https://github.com/kosolabs/swift-libssh/compare/v1.16.0...v1.16.1) (2026-05-07)


### Bug Fixes

* library error code 0 when SSH connection has failed ([#118](https://github.com/kosolabs/swift-libssh/issues/118)) ([5645089](https://github.com/kosolabs/swift-libssh/commit/5645089d9143931c50201031e20c10f9e6c51e2d))

## [1.16.0](https://github.com/kosolabs/swift-libssh/compare/v1.15.0...v1.16.0) (2026-05-05)


### Features

* add convenience functions to read or stream a range ([#116](https://github.com/kosolabs/swift-libssh/issues/116)) ([cdae05f](https://github.com/kosolabs/swift-libssh/commit/cdae05f8de5147e64e7bfb22f09e1318e062e85b))

## [1.15.0](https://github.com/kosolabs/swift-libssh/compare/v1.14.0...v1.15.0) (2026-04-24)


### Features

* add codable to error types ([#113](https://github.com/kosolabs/swift-libssh/issues/113)) ([83eed11](https://github.com/kosolabs/swift-libssh/commit/83eed11a5e9bde698846688fb136ae4e64648f1a))

## [1.14.0](https://github.com/kosolabs/swift-libssh/compare/v1.13.0...v1.14.0) (2026-04-22)


### Features

* add codable to data structs ([#111](https://github.com/kosolabs/swift-libssh/issues/111)) ([4754bff](https://github.com/kosolabs/swift-libssh/commit/4754bff04d1fe44f851f22e953c7244c73d5d0f8))

## [1.13.0](https://github.com/kosolabs/swift-libssh/compare/v1.12.2...v1.13.0) (2026-03-15)


### Features

* add function to recursively remove a directory ([#104](https://github.com/kosolabs/swift-libssh/issues/104)) ([ad77c3c](https://github.com/kosolabs/swift-libssh/commit/ad77c3c5194bdae55f8f6d8f5c44f44c88fbe1e0))

## [1.12.2](https://github.com/kosolabs/swift-libssh/compare/v1.12.1...v1.12.2) (2026-03-14)


### Bug Fixes

* expose fields in SFTPLimits ([#102](https://github.com/kosolabs/swift-libssh/issues/102)) ([d8555c0](https://github.com/kosolabs/swift-libssh/commit/d8555c02456794baf8487fde9b3b516fd0904d2a))

## [1.12.1](https://github.com/kosolabs/swift-libssh/compare/v1.12.0...v1.12.1) (2026-03-13)


### Bug Fixes

* tidy up buffer size implementation ([#99](https://github.com/kosolabs/swift-libssh/issues/99)) ([4e172e1](https://github.com/kosolabs/swift-libssh/commit/4e172e15850477855a067525d3a4bfbb1a65aed9))

## [1.12.0](https://github.com/kosolabs/swift-libssh/compare/v1.11.2...v1.12.0) (2026-03-13)


### Features

* allow user to specify read/write buffer sizes clamped to server limits ([#98](https://github.com/kosolabs/swift-libssh/issues/98)) ([17db9e8](https://github.com/kosolabs/swift-libssh/commit/17db9e893d756e36fe409ade146d02b66de9911f))


### Bug Fixes

* tweak timeouts so that transfers don't fail ([#96](https://github.com/kosolabs/swift-libssh/issues/96)) ([0b5ae34](https://github.com/kosolabs/swift-libssh/commit/0b5ae3421c1a28f0f13a4e35ad1c49551dfff450))

## [1.11.2](https://github.com/kosolabs/swift-libssh/compare/v1.11.1...v1.11.2) (2026-03-12)


### Bug Fixes

* remove test CLI from external products ([#94](https://github.com/kosolabs/swift-libssh/issues/94)) ([c8fbc1a](https://github.com/kosolabs/swift-libssh/commit/c8fbc1a5a80b0b90411cbf61c78f9b6a3b092925))

## [1.11.1](https://github.com/kosolabs/swift-libssh/compare/v1.11.0...v1.11.1) (2026-03-12)


### Bug Fixes

* error handling of aio write wait and add test cli ([#92](https://github.com/kosolabs/swift-libssh/issues/92)) ([e33f0bb](https://github.com/kosolabs/swift-libssh/commit/e33f0bb27fbf9610989c79aa9900e06512137ef8))

## [1.11.0](https://github.com/kosolabs/swift-libssh/compare/v1.10.0...v1.11.0) (2026-02-25)


### Features

* add support for setting any sftp attribute and connection timeout ([5daf610](https://github.com/kosolabs/swift-libssh/commit/5daf6103c437e397a8936ce3abcdd17701cac5de))

## [1.10.0](https://github.com/kosolabs/swift-libssh/compare/v1.9.0...v1.10.0) (2026-02-24)


### Features

* support macOS 15.0 and build against swift 6.1 ([#88](https://github.com/kosolabs/swift-libssh/issues/88)) ([a3f4e37](https://github.com/kosolabs/swift-libssh/commit/a3f4e373dfabdaea2f35621a4bf5f0de06a09d9e))

## [1.9.0](https://github.com/kosolabs/swift-libssh/compare/v1.8.0...v1.9.0) (2026-02-20)


### Features

* add support for moving and rename files ([#85](https://github.com/kosolabs/swift-libssh/issues/85)) ([b087fb7](https://github.com/kosolabs/swift-libssh/commit/b087fb7f79535959f09d2059f12b48503be6a850))

## [1.8.0](https://github.com/kosolabs/swift-libssh/compare/v1.7.1...v1.8.0) (2026-02-19)


### Features

* add support for removing files ([#83](https://github.com/kosolabs/swift-libssh/issues/83)) ([3e49dbe](https://github.com/kosolabs/swift-libssh/commit/3e49dbe8b983b5fdb172fa50ffeefa985d316453))

## [1.7.1](https://github.com/kosolabs/swift-libssh/compare/v1.7.0...v1.7.1) (2026-02-17)


### Bug Fixes

* all errors into a single error enum ([#81](https://github.com/kosolabs/swift-libssh/issues/81)) ([b360009](https://github.com/kosolabs/swift-libssh/commit/b360009401f59e087cf4b2b5163797476871556c))

## [1.7.0](https://github.com/kosolabs/swift-libssh/compare/v1.6.0...v1.7.0) (2026-02-13)


### Features

* add public initializer for SFTPAttributes ([#77](https://github.com/kosolabs/swift-libssh/issues/77)) ([9a58a3e](https://github.com/kosolabs/swift-libssh/commit/9a58a3e525b04d5b14b9ea620ed988c53d51891f))

## [1.6.0](https://github.com/kosolabs/swift-libssh/compare/v1.5.1...v1.6.0) (2026-02-10)


### Features

* add fstat support ([#74](https://github.com/kosolabs/swift-libssh/issues/74)) ([b508d5c](https://github.com/kosolabs/swift-libssh/commit/b508d5cfa106cca11c8f65341db8aead69e81162))

## [1.5.1](https://github.com/kosolabs/swift-libssh/compare/v1.5.0...v1.5.1) (2026-02-09)


### Bug Fixes

* attr strings should never be nil and access times are dates ([#72](https://github.com/kosolabs/swift-libssh/issues/72)) ([55b7487](https://github.com/kosolabs/swift-libssh/commit/55b748726bd695917aa2e41eb9ebd55d6328127b))

## [1.5.0](https://github.com/kosolabs/swift-libssh/compare/v1.4.0...v1.5.0) (2026-02-08)


### Features

* add support for no auth ([#70](https://github.com/kosolabs/swift-libssh/issues/70)) ([a4e8c3c](https://github.com/kosolabs/swift-libssh/commit/a4e8c3cd1f35f76f36fd60f7dc5bcf620ba62320))


### Bug Fixes

* reorganize code a little ([#68](https://github.com/kosolabs/swift-libssh/issues/68)) ([4eafc48](https://github.com/kosolabs/swift-libssh/commit/4eafc483804e05f94ce1f5c2772a66002a46f6c8))

## [1.4.0](https://github.com/kosolabs/swift-libssh/compare/v1.3.2...v1.4.0) (2026-02-05)


### Features

* add ability to read contents of a directory ([#66](https://github.com/kosolabs/swift-libssh/issues/66)) ([e664141](https://github.com/kosolabs/swift-libssh/commit/e664141702642bbf0d1f9e604c42a2239a77cb25))

## [1.3.2](https://github.com/kosolabs/swift-libssh/compare/v1.3.1...v1.3.2) (2026-01-26)


### Bug Fixes

* make sftp attributes public ([#61](https://github.com/kosolabs/swift-libssh/issues/61)) ([147fa39](https://github.com/kosolabs/swift-libssh/commit/147fa390a6276abfb0ebf2ee83a53cba121d67a7))

## [1.3.1](https://github.com/kosolabs/swift-libssh/compare/v1.3.0...v1.3.1) (2026-01-23)


### Bug Fixes

* restrict port numbers to UInt16 ([#59](https://github.com/kosolabs/swift-libssh/issues/59)) ([93c309d](https://github.com/kosolabs/swift-libssh/commit/93c309d033de8bb982bbe88229213c264a5d77f4))

## [1.3.0](https://github.com/kosolabs/swift-libssh/compare/v1.2.0...v1.3.0) (2026-01-23)


### Features

* add support for base64 encoded private key ([#55](https://github.com/kosolabs/swift-libssh/issues/55)) ([08d888d](https://github.com/kosolabs/swift-libssh/commit/08d888dde14d124275e3ac34a89fd91e66ff5bd0))


### Bug Fixes

* add check for task cancellation ([#58](https://github.com/kosolabs/swift-libssh/issues/58)) ([d746564](https://github.com/kosolabs/swift-libssh/commit/d746564072403b40926d4d31799c8923d9f5494b))
* tweak values in flaky partial read of channel test ([#57](https://github.com/kosolabs/swift-libssh/issues/57)) ([3c19adb](https://github.com/kosolabs/swift-libssh/commit/3c19adbee822a338fa3f1cf1def8f32d8d5b6b64))

## [1.2.0](https://github.com/kosolabs/swift-libssh/compare/v1.1.1...v1.2.0) (2026-01-22)


### Features

* add statically compiled libssh ([#53](https://github.com/kosolabs/swift-libssh/issues/53)) ([a00785e](https://github.com/kosolabs/swift-libssh/commit/a00785eabdf4e6bef1926ff8ab50bc1b3fa87387))

## [1.1.1](https://github.com/kosolabs/swift-libssh/compare/v1.1.0...v1.1.1) (2026-01-18)


### Bug Fixes

* update tests to use scoped resource ([#51](https://github.com/kosolabs/swift-libssh/issues/51)) ([ad3a8d3](https://github.com/kosolabs/swift-libssh/commit/ad3a8d3a5bbf4aedad47d2d6823b8717a21ca858))

## [1.1.0](https://github.com/kosolabs/swift-libssh/compare/v1.0.1...v1.1.0) (2026-01-17)


### Features

* provide SSHClient as a scoped resource ([#50](https://github.com/kosolabs/swift-libssh/issues/50)) ([175cf7e](https://github.com/kosolabs/swift-libssh/commit/175cf7ed35895cdcff6fedab677d5dc3bf6699c9))


### Bug Fixes

* use environment and drop tagging code ([#48](https://github.com/kosolabs/swift-libssh/issues/48)) ([4146b88](https://github.com/kosolabs/swift-libssh/commit/4146b887c5433e0d61cc6e4d22ba83a4382e2bf8))

## [1.0.1](https://github.com/kosolabs/swift-libssh/compare/v1.0.0...v1.0.1) (2026-01-16)


### Bug Fixes

* release please take 2 ([#46](https://github.com/kosolabs/swift-libssh/issues/46)) ([37ff3c0](https://github.com/kosolabs/swift-libssh/commit/37ff3c0f368a7f9f6995599286a0248064e63f90))

## 1.0.0 (2026-01-15)


### Features

* add exit code and stderr support to execute ([#42](https://github.com/kosolabs/swift-libssh/issues/42)) ([570b9a6](https://github.com/kosolabs/swift-libssh/commit/570b9a6f6c3c49b16bc6bd4a0b80469d7230919e))
* add progress callback to upload ([#32](https://github.com/kosolabs/swift-libssh/issues/32)) ([7dd6581](https://github.com/kosolabs/swift-libssh/commit/7dd6581e6f4f43f8b7f9ea1dcba331d4c1d50157))
* add support for streaming writes ([#39](https://github.com/kosolabs/swift-libssh/issues/39)) ([774b1ea](https://github.com/kosolabs/swift-libssh/commit/774b1ea4f16e1bbd931c013d1eea1ea11a197396))
* enable release please ([#44](https://github.com/kosolabs/swift-libssh/issues/44)) ([947e554](https://github.com/kosolabs/swift-libssh/commit/947e55435dbbfedbe47c0e9bc3cea673b06c67ca))
* implement read offset and read length ([#33](https://github.com/kosolabs/swift-libssh/issues/33)) ([172aa48](https://github.com/kosolabs/swift-libssh/commit/172aa48b228f2b62266699c23d99544bd82be9a2))
* initial implementation of upload ([#30](https://github.com/kosolabs/swift-libssh/issues/30)) ([1d14a45](https://github.com/kosolabs/swift-libssh/commit/1d14a45770ad0647726e69530844fd216c9666d8))


### Bug Fixes

* add [@shadanan](https://github.com/shadanan) as codeowner ([#37](https://github.com/kosolabs/swift-libssh/issues/37)) ([f6f5c35](https://github.com/kosolabs/swift-libssh/commit/f6f5c352e001721a7ab81c791b7f365bde28c057))
* allow renovate to manage pinned version ([#38](https://github.com/kosolabs/swift-libssh/issues/38)) ([0e418e8](https://github.com/kosolabs/swift-libssh/commit/0e418e8b3b14815ada46132f2844d43238e854fa))
* avoid second allocation of Data ([#31](https://github.com/kosolabs/swift-libssh/issues/31)) ([0bc62b7](https://github.com/kosolabs/swift-libssh/commit/0bc62b736b44d7341761d5326547e3a1529b9a78))
* remove dead code ([#29](https://github.com/kosolabs/swift-libssh/issues/29)) ([2e95ba9](https://github.com/kosolabs/swift-libssh/commit/2e95ba91aebf55196511ee0ce3e51e1a606da449))
* remove untested code ([#41](https://github.com/kosolabs/swift-libssh/issues/41)) ([cff193a](https://github.com/kosolabs/swift-libssh/commit/cff193a95b73c889d8280855e3c976204f5a0a91))
* simplify channel session management ([#43](https://github.com/kosolabs/swift-libssh/issues/43)) ([2ca78a3](https://github.com/kosolabs/swift-libssh/commit/2ca78a38f6872fc994db57f0a1775bca00a9fb30))
* tidy up naming ([#40](https://github.com/kosolabs/swift-libssh/issues/40)) ([78b680b](https://github.com/kosolabs/swift-libssh/commit/78b680b7d41f1f2725260f8f18636e82c2d9d53f))
