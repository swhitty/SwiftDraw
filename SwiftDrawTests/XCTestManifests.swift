import XCTest

extension AttributeParserTests {
    static let __allTests = [
        ("testDictionary", testDictionary),
        ("testParseBool", testParseBool),
        ("testParseFloat", testParseFloat),
        ("testParseFloats", testParseFloats),
        ("testParseLength", testParseLength),
        ("testParsePoints", testParsePoints),
        ("testParserOrder", testParserOrder),
        ("testParseString", testParseString),
        ("testParseURL", testParseURL),
        ("testParseURLSelector", testParseURLSelector),
    ]
}

extension CommandLineArgumentsTests {
    static let __allTests = [
        ("testParseModifiers", testParseModifiers),
        ("testParseModifiersThrowsForDuplicateModifiers", testParseModifiersThrowsForDuplicateModifiers),
        ("testParseModifiersThrowsForMissingPrefix", testParseModifiersThrowsForMissingPrefix),
        ("testParseModifiersThrowsForOddPairs", testParseModifiersThrowsForOddPairs),
        ("testParseModifiersThrowsForUnknownModifiers", testParseModifiersThrowsForUnknownModifiers),
    ]
}

extension CommandLineConfigurationTests {
    static let __allTests = [
        ("testNewURLForFormat", testNewURLForFormat),
        ("testParseConfiguration", testParseConfiguration),
        ("testParseConfigurationThrows", testParseConfigurationThrows),
        ("testParseFileURL", testParseFileURL),
    ]
}

extension CoordinateTests {
    static let __allTests = [
        ("testDelimeterComma", testDelimeterComma),
        ("testDelimeterSpace", testDelimeterSpace),
        ("testPrecisionCapped", testPrecisionCapped),
        ("testPrecisionMax", testPrecisionMax),
    ]
}

extension DOMElementTests {
    static let __allTests = [
        ("testCircle", testCircle),
        ("testEllipse", testEllipse),
        ("testGroup", testGroup),
        ("testLine", testLine),
        ("testPolygon", testPolygon),
        ("testPolyline", testPolyline),
        ("testRect", testRect),
        ("testText", testText),
    ]
}

extension GradientTests {
    static let __allTests = [
        ("testLinerGradient", testLinerGradient),
        ("testLinerGradientStop", testLinerGradientStop),
    ]
}

extension LayerTreeBuilderLayerTests {
    static let __allTests = [
        ("testMakeImageContentsFromDOM", testMakeImageContentsFromDOM),
        ("testMakeTextContentsFromDOM", testMakeTextContentsFromDOM),
        ("testMakeUseContentsFromDOM", testMakeUseContentsFromDOM),
        ("testMakeUseContentsThrows", testMakeUseContentsThrows),
    ]
}

extension LayerTreeBuilderShapeTests {
    static let __allTests = [
        ("testDOMRectMakesRect", testDOMRectMakesRect),
        ("testDOMRectMakesRectWithDefaultOrigin", testDOMRectMakesRectWithDefaultOrigin),
    ]
}

extension LayerTreeBuilderTests {
    static let __allTests = [
        ("testDOMClipMakesShape", testDOMClipMakesShape),
        ("testDOMGroupMakesChildContents", testDOMGroupMakesChildContents),
        ("testDOMMaskMakesLayer", testDOMMaskMakesLayer),
        ("testMakeViewBoxTransform", testMakeViewBoxTransform),
        ("testStrokeAttributes", testStrokeAttributes),
    ]
}

extension LayerTreeColorTests {
    static let __allTests = [
        ("testFromDOM", testFromDOM),
        ("testLuminanceConverter", testLuminanceConverter),
        ("testLuminanceToAlpha", testLuminanceToAlpha),
        ("testMultiplyingAlpha", testMultiplyingAlpha),
        ("testRGBi", testRGBi),
        ("testStaticColors", testStaticColors),
        ("testWithAlpha", testWithAlpha),
    ]
}

extension LayerTreeCommandGeneratorTests {
    static let __allTests = [
        ("testClip", testClip),
        ("testTransforms", testTransforms),
    ]
}

extension LayerTreeImageTests {
    static let __allTests = [
        ("testImageEquality", testImageEquality),
        ("testInit", testInit),
    ]
}

extension LayerTreeLayerTests {
    static let __allTests = [
        ("testContentsTextEquality", testContentsTextEquality),
        ("testLayersWithComplexContentsAreAppendedWithoutLayer", testLayersWithComplexContentsAreAppendedWithoutLayer),
        ("testLayersWithSimpleContentsAreAppendedWithoutLayer", testLayersWithSimpleContentsAreAppendedWithoutLayer),
    ]
}

extension LayerTreePathTests {
    static let __allTests = [
        ("testClose", testClose),
        ("testCubic", testCubic),
        ("testCubicSmoothAbsolute", testCubicSmoothAbsolute),
        ("testCubicSmoothRelative", testCubicSmoothRelative),
        ("testDOMCubicSmooth", testDOMCubicSmooth),
        ("testDOMQuadraticSmooth", testDOMQuadraticSmooth),
        ("testHorizontal", testHorizontal),
        ("testLine", testLine),
        ("testMove", testMove),
        ("testQuadraticBalanced", testQuadraticBalanced),
        ("testQuadraticSmoothAbsolute", testQuadraticSmoothAbsolute),
        ("testQuadraticUnbalanced", testQuadraticUnbalanced),
        ("testVertical", testVertical),
    ]
}

extension LayerTreeShapeTests {
    static let __allTests = [
        ("testCircleBuilder", testCircleBuilder),
        ("testEllipseBuilder", testEllipseBuilder),
        ("testLineBuilder", testLineBuilder),
        ("testPathBuilder", testPathBuilder),
        ("testPolygonBuilder", testPolygonBuilder),
        ("testPolylineBuilder", testPolylineBuilder),
        ("testRectBuilder", testRectBuilder),
        ("testShapeEquality", testShapeEquality),
    ]
}

extension LayerTreeTransformTests {
    static let __allTests = [
        ("testDOMMakesLayerTreeTranslate", testDOMMakesLayerTreeTranslate),
        ("testDOMMakesMatrixTransform", testDOMMakesMatrixTransform),
        ("testDOMMakesMultipleTransforms", testDOMMakesMultipleTransforms),
        ("testDOMMakesRotatePointTransform", testDOMMakesRotatePointTransform),
        ("testDOMMakesRotateTransform", testDOMMakesRotateTransform),
        ("testDOMMakesScaleTransform", testDOMMakesScaleTransform),
        ("testDOMMakesSkewXTransform", testDOMMakesSkewXTransform),
        ("testDOMMakesSkewYTransform", testDOMMakesSkewYTransform),
        ("testMatrixConcatenation", testMatrixConcatenation),
        ("testRotateMatrix", testRotateMatrix),
        ("testScaleMatrix", testScaleMatrix),
        ("testSkewXMatrix", testSkewXMatrix),
        ("testSkewYMatrix", testSkewYMatrix),
        ("testTranslateMatrix", testTranslateMatrix),
    ]
}

extension ParserColorTests {
    static let __allTests = [
        ("testColorHex", testColorHex),
        ("testColorKeyword", testColorKeyword),
        ("testColorNone", testColorNone),
        ("testColorRGBf", testColorRGBf),
        ("testColorRGBi", testColorRGBi),
    ]
}

extension ParserGraphicAttributeTests {
    static let __allTests = [
        ("testCircle", testCircle),
        ("testDisplayMode", testDisplayMode),
        ("testPresentationAttributes", testPresentationAttributes),
        ("testStrokeLineCap", testStrokeLineCap),
        ("testStrokeLineJoin", testStrokeLineJoin),
    ]
}

extension ParserTransformTests {
    static let __allTests = [
        ("testMatrix", testMatrix),
        ("testRotate", testRotate),
        ("testRotatePoint", testRotatePoint),
        ("testScale", testScale),
        ("testSkewX", testSkewX),
        ("testSkewY", testSkewY),
        ("testTransform", testTransform),
        ("testTranslate", testTranslate),
    ]
}

extension ParserXMLGradientTests {
    static let __allTests = [
        ("testParseGradients", testParseGradients),
    ]
}

extension ParserXMLPathTests {
    static let __allTests = [
        ("testArc", testArc),
        ("testClose", testClose),
        ("testCubic", testCubic),
        ("testCubicSmooth", testCubicSmooth),
        ("testEquality", testEquality),
        ("testHorizontal", testHorizontal),
        ("testLine", testLine),
        ("testMove", testMove),
        ("testPath", testPath),
        ("testPathLineBreak", testPathLineBreak),
        ("testQuadratic", testQuadratic),
        ("testQuadraticSmooth", testQuadraticSmooth),
        ("testScanBool", testScanBool),
        ("testScanCoordinate", testScanCoordinate),
        ("testVerical", testVerical),
    ]
}

extension ParserXMLTextTests {
    static let __allTests = [
        ("testEmptyTextNodeReturnsNil", testEmptyTextNodeReturnsNil),
        ("testParseText", testParseText),
        ("testTextNodeParses", testTextNodeParses),
    ]
}

extension RendererTests {
    static let __allTests = [
        ("testPerformCommands", testPerformCommands),
    ]
}

extension SAXParserTests {
    static let __allTests = [
        ("testInvalidXMLThrows", testInvalidXMLThrows),
        ("testMissingFileThrows", testMissingFileThrows),
        ("testUnexpectedElementsThrows", testUnexpectedElementsThrows),
        ("testUnexpectedNamespaceElementsSkipped", testUnexpectedNamespaceElementsSkipped),
        ("testValidSVGParses", testValidSVGParses),
    ]
}

extension SVGTests {
    static let __allTests = [
        ("testClipPath", testClipPath),
        ("testParseSVGInvalidNode", testParseSVGInvalidNode),
        ("testParseSVGMissingHeightInvalidNode", testParseSVGMissingHeightInvalidNode),
        ("testParseSVGMissingWidthInvalidNode", testParseSVGMissingWidthInvalidNode),
        ("testSVG", testSVG),
        ("testViewBox", testViewBox),
    ]
}

extension ScannerTests {
    static let __allTests = [
        ("testIsEOF", testIsEOF),
        ("testScanBool", testScanBool),
        ("testScanCase", testScanCase),
        ("testScanCharacter", testScanCharacter),
        ("testScanCharsetEmoji", testScanCharsetEmoji),
        ("testScanCharsetHex", testScanCharsetHex),
        ("testScanCoordinate", testScanCoordinate),
        ("testScanDouble", testScanDouble),
        ("testScanFloat", testScanFloat),
        ("testScanLength", testScanLength),
        ("testScanPercentage", testScanPercentage),
        ("testScanPercentageFloat", testScanPercentageFloat),
        ("testScanString", testScanString),
        ("testScanUInt8", testScanUInt8),
    ]
}

extension StackTests {
    static let __allTests = [
        ("testInit", testInit),
        ("testMutation", testMutation),
        ("testPop", testPop),
        ("testPush", testPush),
    ]
}

extension StyleTests {
    static let __allTests = [
        ("testStyle", testStyle),
        ("testStyles", testStyles),
    ]
}

extension URLTests {
    static let __allTests = [
        ("testDataURL", testDataURL),
        ("testDecodedData", testDecodedData),
        ("testDecodedDataLineBreak", testDecodedDataLineBreak),
    ]
}

extension UseTests {
    static let __allTests = [
        ("testUse", testUse),
    ]
}

extension ValueParserTests {
    static let __allTests = [
        ("testBool", testBool),
        ("testFill", testFill),
        ("testCoordinate", testCoordinate),
        ("testFloat", testFloat),
        ("testFloats", testFloats),
        ("testLength", testLength),
        ("testPercentage", testPercentage),
        ("testPoints", testPoints),
        ("testRaw", testRaw),
        ("testUrl", testUrl),
        ("testUrlSelector", testUrlSelector),
    ]
}

extension XMLParserElementTests {
    static let __allTests = [
        ("testCircle", testCircle),
        ("testElementParserErrorsPreserveLineNumbers", testElementParserErrorsPreserveLineNumbers),
        ("testElementParserErrorsPreserveLineNumbersFromElement", testElementParserErrorsPreserveLineNumbersFromElement),
        ("testElementParserSkipsErrors", testElementParserSkipsErrors),
        ("testEllipse", testEllipse),
        ("testLine", testLine),
        ("testPolygon", testPolygon),
        ("testPolygonFillRule", testPolygonFillRule),
        ("testPolyline", testPolyline),
        ("testRect", testRect),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AttributeParserTests.__allTests),
        testCase(CommandLineArgumentsTests.__allTests),
        testCase(CommandLineConfigurationTests.__allTests),
        testCase(CoordinateTests.__allTests),
        testCase(DOMElementTests.__allTests),
        testCase(GradientTests.__allTests),
        testCase(LayerTreeBuilderLayerTests.__allTests),
        testCase(LayerTreeBuilderShapeTests.__allTests),
        testCase(LayerTreeBuilderTests.__allTests),
        testCase(LayerTreeColorTests.__allTests),
        testCase(LayerTreeCommandGeneratorTests.__allTests),
        testCase(LayerTreeImageTests.__allTests),
        testCase(LayerTreeLayerTests.__allTests),
        testCase(LayerTreePathTests.__allTests),
        testCase(LayerTreeShapeTests.__allTests),
        testCase(LayerTreeTransformTests.__allTests),
        testCase(ParserColorTests.__allTests),
        testCase(ParserGraphicAttributeTests.__allTests),
        testCase(ParserTransformTests.__allTests),
        testCase(ParserXMLGradientTests.__allTests),
        testCase(ParserXMLPathTests.__allTests),
        testCase(ParserXMLPatternTests.__allTests),
        testCase(ParserXMLTextTests.__allTests),
        testCase(RendererTests.__allTests),
        testCase(SAXParserTests.__allTests),
        testCase(SVGTests.__allTests),
        testCase(ScannerTests.__allTests),
        testCase(StackTests.__allTests),
        testCase(StyleTests.__allTests),
        testCase(URLTests.__allTests),
        testCase(UseTests.__allTests),
        testCase(ValueParserTests.__allTests),
        testCase(XMLParserElementTests.__allTests),
    ]
}
#endif
