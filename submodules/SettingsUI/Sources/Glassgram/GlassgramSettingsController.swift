import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import WallpaperBackgroundNode
import ChatMessageBackground

/// Glassgram: icon for the Settings row (chat bubble on a blue-to-cyan gradient).
public let glassgramSettingsIcon: UIImage? = renderSettingsIcon(name: "Item List/Icons/Chat", backgroundColors: [UIColor(rgb: 0x0045ff), UIColor(rgb: 0x5ae6ff)])

/// One labeled slider: title on the left, percentage on the right, slider below.
private final class GlassSliderRowView: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()

    var onChange: ((CGFloat) -> Void)?

    var value: CGFloat {
        get {
            return CGFloat(self.slider.value)
        }
        set {
            self.slider.value = Float(newValue)
            self.updateValueLabel()
        }
    }

    init(title: String) {
        super.init(frame: CGRect())
        self.titleLabel.text = title
        self.titleLabel.font = UIFont.systemFont(ofSize: 17.0)
        self.valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15.0, weight: .regular)
        self.valueLabel.textAlignment = .right
        self.slider.minimumValue = 0.0
        self.slider.maximumValue = 1.0
        self.slider.addTarget(self, action: #selector(self.sliderChanged), for: .valueChanged)
        self.addSubview(self.titleLabel)
        self.addSubview(self.valueLabel)
        self.addSubview(self.slider)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTheme(_ theme: PresentationTheme) {
        self.titleLabel.textColor = theme.list.itemPrimaryTextColor
        self.valueLabel.textColor = theme.list.itemSecondaryTextColor
        self.slider.minimumTrackTintColor = theme.list.itemAccentColor
    }

    @objc private func sliderChanged() {
        self.updateValueLabel()
        self.onChange?(self.value)
    }

    private func updateValueLabel() {
        self.valueLabel.text = "\(Int((self.value * 100.0).rounded()))%"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let valueWidth: CGFloat = 60.0
        self.titleLabel.frame = CGRect(x: 0.0, y: 0.0, width: self.bounds.width - valueWidth, height: 22.0)
        self.valueLabel.frame = CGRect(x: self.bounds.width - valueWidth, y: 0.0, width: valueWidth, height: 22.0)
        self.slider.frame = CGRect(x: 0.0, y: 28.0, width: self.bounds.width, height: 30.0)
    }
}

private final class GlassgramSettingsControllerNode: ASDisplayNode {
    private let presentationData: PresentationData

    private let chatBackgroundNode: WallpaperBackgroundNode
    private let incomingBubble = ChatMessageBackground()
    private let outgoingBubble = ChatMessageBackground()
    private let incomingLabel = UILabel()
    private let outgoingLabel = UILabel()

    private let scrollView = UIScrollView()
    private let glassHeader = UILabel()
    private let tintRow = GlassSliderRowView(title: "Glass Tint")
    private let rimTopRow = GlassSliderRowView(title: "Rim Brightness – Top")
    private let rimMiddleRow = GlassSliderRowView(title: "Rim Brightness – Sides")
    private let rimBottomRow = GlassSliderRowView(title: "Rim Brightness – Bottom")
    private let resetButton = UIButton(type: .system)

    private var sliderRows: [GlassSliderRowView] {
        return [self.tintRow, self.rimTopRow, self.rimMiddleRow, self.rimBottomRow]
    }

    private let previewHeight: CGFloat = 200.0
    private let rowHeight: CGFloat = 60.0
    private let rowSpacing: CGFloat = 16.0
    private let tailWidth: CGFloat = 6.0
    private let bubblePadding = UIEdgeInsets(top: 8.0, left: 12.0, bottom: 8.0, right: 12.0)

    init(context: AccountContext, presentationData: PresentationData) {
        self.presentationData = presentationData
        self.chatBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
        self.chatBackgroundNode.displaysAsynchronously = false

        super.init()

        self.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.addSubnode(self.chatBackgroundNode)
        self.addSubnode(self.incomingBubble)
        self.addSubnode(self.outgoingBubble)

        self.chatBackgroundNode.update(wallpaper: presentationData.chatWallpaper, animated: false)
        self.chatBackgroundNode.updateBubbleTheme(bubbleTheme: presentationData.theme, bubbleCorners: presentationData.chatBubbleCorners)
    }

    override func didLoad() {
        super.didLoad()

        let theme = self.presentationData.theme

        self.configureBubble(self.incomingBubble, label: self.incomingLabel, incoming: true, text: "Have you seen the new glass bubbles?")
        self.configureBubble(self.outgoingBubble, label: self.outgoingLabel, incoming: false, text: "Yes! Move the sliders below to tune them ✨")
        self.view.addSubview(self.incomingLabel)
        self.view.addSubview(self.outgoingLabel)

        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)

        self.glassHeader.text = "GLASS"
        self.glassHeader.font = UIFont.systemFont(ofSize: 13.0)
        self.glassHeader.textColor = theme.list.freeTextColor
        self.scrollView.addSubview(self.glassHeader)

        let settings = GlassBubbleSettings.current
        self.tintRow.value = settings.tintAlpha
        self.rimTopRow.value = settings.rimTopAlpha
        self.rimMiddleRow.value = settings.rimMiddleAlpha
        self.rimBottomRow.value = settings.rimBottomAlpha

        for row in self.sliderRows {
            row.updateTheme(theme)
            row.onChange = { [weak self] _ in
                self?.slidersChanged()
            }
            self.scrollView.addSubview(row)
        }

        self.resetButton.setTitle("Reset to Defaults", for: .normal)
        self.resetButton.setTitleColor(theme.list.itemAccentColor, for: .normal)
        self.resetButton.titleLabel?.font = UIFont.systemFont(ofSize: 17.0)
        self.resetButton.addTarget(self, action: #selector(self.resetPressed), for: .touchUpInside)
        self.scrollView.addSubview(self.resetButton)
    }

    private func configureBubble(_ bubble: ChatMessageBackground, label: UILabel, incoming: Bool, text: String) {
        let presentationData = self.presentationData
        let hasWallpaper = presentationData.chatWallpaper.hasWallpaper
        let graphics = PresentationResourcesChat.principalGraphics(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper, bubbleCorners: presentationData.chatBubbleCorners)

        bubble.setType(type: incoming ? .incoming(.None) : .outgoing(.None), highlighted: false, graphics: graphics, maskMode: false, hasWallpaper: hasWallpaper, transition: .immediate, backgroundNode: self.chatBackgroundNode)

        let messageTheme = incoming ? presentationData.theme.chat.message.incoming : presentationData.theme.chat.message.outgoing
        let fill = hasWallpaper ? messageTheme.bubble.withWallpaper.fill : messageTheme.bubble.withoutWallpaper.fill
        bubble.setGlass(tint: fill.first, isDark: presentationData.theme.overallDarkAppearance)

        label.text = text
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 17.0)
        label.textColor = messageTheme.primaryTextColor
    }

    private func slidersChanged() {
        GlassBubbleSettings.current = GlassBubbleSettings(
            tintAlpha: self.tintRow.value,
            rimTopAlpha: self.rimTopRow.value,
            rimMiddleAlpha: self.rimMiddleRow.value,
            rimBottomAlpha: self.rimBottomRow.value
        )
    }

    @objc private func resetPressed() {
        let defaults = GlassBubbleSettings.defaults
        self.tintRow.value = defaults.tintAlpha
        self.rimTopRow.value = defaults.rimTopAlpha
        self.rimMiddleRow.value = defaults.rimMiddleAlpha
        self.rimBottomRow.value = defaults.rimBottomAlpha
        GlassBubbleSettings.current = defaults
    }

    /// Places a bubble with its text; returns the bubble height.
    private func layoutBubble(_ bubble: ChatMessageBackground, label: UILabel, incoming: Bool, y: CGFloat, width: CGFloat, sideInset: CGFloat) -> CGFloat {
        let maxTextWidth = min(260.0, width - sideInset * 2.0 - 60.0)
        let textSize = label.sizeThatFits(CGSize(width: maxTextWidth, height: CGFloat.greatestFiniteMagnitude))
        let textWidth = ceil(min(textSize.width, maxTextWidth))
        let textHeight = ceil(textSize.height)
        let bubbleSize = CGSize(width: textWidth + self.bubblePadding.left + self.bubblePadding.right + self.tailWidth, height: max(textHeight + self.bubblePadding.top + self.bubblePadding.bottom, 34.0))
        let x = incoming ? sideInset : width - sideInset - bubbleSize.width

        bubble.frame = CGRect(origin: CGPoint(x: x, y: y), size: bubbleSize)
        bubble.updateLayout(size: bubbleSize, transition: ContainedViewLayoutTransition.immediate)

        let textX = x + self.bubblePadding.left + (incoming ? self.tailWidth : 0.0)
        label.frame = CGRect(x: textX, y: y + floor((bubbleSize.height - textHeight) / 2.0), width: textWidth, height: textHeight)
        return bubbleSize.height
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let width = layout.size.width
        let sideInset = layout.safeInsets.left + 16.0

        let previewFrame = CGRect(x: 0.0, y: navigationBarHeight, width: width, height: self.previewHeight)
        self.chatBackgroundNode.frame = previewFrame
        self.chatBackgroundNode.updateLayout(size: previewFrame.size, displayMode: .aspectFill, transition: .immediate)

        let incomingHeight = self.layoutBubble(self.incomingBubble, label: self.incomingLabel, incoming: true, y: previewFrame.minY + 30.0, width: width, sideInset: sideInset)
        let _ = self.layoutBubble(self.outgoingBubble, label: self.outgoingLabel, incoming: false, y: previewFrame.minY + 30.0 + incomingHeight + 12.0, width: width, sideInset: sideInset)

        self.scrollView.frame = CGRect(x: 0.0, y: previewFrame.maxY, width: width, height: max(0.0, layout.size.height - previewFrame.maxY))

        let rowWidth = width - sideInset * 2.0
        var y: CGFloat = 24.0
        self.glassHeader.frame = CGRect(x: sideInset, y: y, width: rowWidth, height: 18.0)
        y += 18.0 + 12.0
        for row in self.sliderRows {
            row.frame = CGRect(x: sideInset, y: y, width: rowWidth, height: self.rowHeight)
            y += self.rowHeight + self.rowSpacing
        }
        self.resetButton.frame = CGRect(x: sideInset, y: y, width: rowWidth, height: 44.0)
        y += 44.0 + 24.0 + layout.intrinsicInsets.bottom

        self.scrollView.contentSize = CGSize(width: width, height: y)
    }
}

/// Glassgram settings: live preview of two glass bubbles over the chat wallpaper,
/// plus sliders for each GlassBubbleSettings value.
public final class GlassgramSettingsController: ViewController {
    private let context: AccountContext
    private let presentationData: PresentationData

    private var controllerNode: GlassgramSettingsControllerNode {
        return self.displayNode as! GlassgramSettingsControllerNode
    }

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings))

        self.navigationItem.title = "Glassgram"
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = GlassgramSettingsControllerNode(context: self.context, presentationData: self.presentationData)
        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
