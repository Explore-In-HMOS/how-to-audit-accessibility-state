import { ArcList, ArcListAttribute, ArcListItem, ArcListItemAttribute, LengthMetrics } from '@kit.ArkUI';
import {
  AccessibilityStatus,
  StartMode,
  TouchMode,
  createDefaultAccessibilityStatus,
  getAccessibilityStatus
} from '../services/AccessibilityStatusService';

@Entry
@Component
struct Index {
  @Provide('NavPathStack') pageStack: NavPathStack = new NavPathStack();
  @State status: AccessibilityStatus = createDefaultAccessibilityStatus();

  onPageShow(): void {
    this.refreshStatus();
  }

  /**
   * Refreshes all AccessibilityKit-derived state before rendering or navigation.
   * This keeps the visible mode in sync with system settings changed during testing.
   */
  private refreshStatus(): void {
    this.status = getAccessibilityStatus();
  }

  /**
   * Converts raw touch mode values into short labels that fit the circular watch UI.
   */
  private touchModeLabel(touchMode: TouchMode): Resource {
    if (touchMode === 'singleTouchMode') {
      return $r('app.string.touch_single');
    }
    if (touchMode === 'doubleTouchMode') {
      return $r('app.string.touch_double');
    }
    if (touchMode === 'none') {
      return $r('app.string.touch_none');
    }
    return $r('app.string.touch_unknown');
  }

  /**
   * Returns a mode color used consistently by the start screen and walking screen.
   */
  private modeColor(mode: StartMode): Resource {
    if (mode === 'doubleTouch') {
      return $r('app.color.mode_double_touch');
    }
    if (mode === 'accessible') {
      return $r('app.color.mode_accessible');
    }
    if (mode === 'fallback') {
      return $r('app.color.mode_fallback');
    }
    return $r('app.color.mode_standard');
  }

  /**
   * Maps the internal mode code to localized display text.
   */
  private modeText(mode: StartMode): Resource {
    if (mode === 'doubleTouch') {
      return $r('app.string.mode_double_touch');
    }
    if (mode === 'accessible') {
      return $r('app.string.mode_accessible');
    }
    if (mode === 'fallback') {
      return $r('app.string.mode_fallback');
    }
    return $r('app.string.mode_standard');
  }

  /**
   * Builds one compact status chip for accessibility, touch guide, or extension count.
   */
  @Builder
  StatusChip(label: Resource, value: Resource | string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(9)
        .fontColor($r('app.color.text_tertiary'))
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .width('100%')

      Text(value)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .height(46)
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 4, right: 4 })
    .backgroundColor($r('app.color.chip_bg'))
    .borderRadius(8)
  }

  /**
   * Maps Navigation route names to destination components.
   * NavPathStack is used instead of router so the sample follows current ArkUI patterns.
   */
  @Builder
  PageMap(name: string) {
    if (name === 'WalkingStarted') {
      WalkingStarted({ status: this.status })
    }
  }

  build() {
    Navigation(this.pageStack) {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width('94%')
          .height('94%')
          .fill($r('app.color.face_bg'))

        ArcList({ initialIndex: 0 }) {
          ArcListItem() {
            Text($r('app.string.app_name'))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
              .width('74%')
          }
          .align(Alignment.Center)

          ArcListItem() {
            Column({ space: 5 }) {
              Text(this.modeText(this.status.mode))
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.modeColor(this.status.mode))
                .textAlign(TextAlign.Center)
                .width('100%')

              Row() {
                Circle()
                  .width(6)
                  .height(6)
                  .fill(this.modeColor(this.status.mode))
                  .margin({ right: 6 })

                Text(this.touchModeLabel(this.status.touchMode))
                  .fontSize(10)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
              }
              .justifyContent(FlexAlign.Center)
              .width('100%')
            }
            .width('78%')
            .padding({ top: 8, bottom: 8 })
            .backgroundColor($r('app.color.mode_panel_bg'))
            .borderRadius(8)
          }
          .align(Alignment.Center)

          ArcListItem() {
            Column({ space: 7 }) {
              Text($r('app.string.route_instruction'))
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.route_primary'))
                .textAlign(TextAlign.Center)
                .maxLines(2)
                .width('100%')

              Text($r('app.string.route_eta'))
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
                .width('100%')
            }
            .width('82%')
            .padding({ left: 10, right: 10, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.panel_bg'))
            .borderRadius(8)
          }
          .align(Alignment.Center)

          ArcListItem() {
            Row({ space: 5 }) {
              this.StatusChip($r('app.string.label_a11y'),
                this.status.accessibilityEnabled ? $r('app.string.value_on') : $r('app.string.value_off'))
              this.StatusChip($r('app.string.label_guide'),
                this.status.touchGuideEnabled ? $r('app.string.value_on') : $r('app.string.value_off'))
              this.StatusChip($r('app.string.label_extensions'), `${this.status.enabledExtensionCount}`)
            }
            .width('80%')
          }
          .align(Alignment.Center)

          if (this.status.enabledExtensionNames.length > 0) {
            ArcListItem() {
              Text(this.status.enabledExtensionNames.join(', '))
                .fontSize(9)
                .fontColor($r('app.color.text_tertiary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .textAlign(TextAlign.Center)
                .width('70%')
            }
            .align(Alignment.Center)
          }

          ArcListItem() {
            Button($r('app.string.start_walking'))
              .width('78%')
              .height(40)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.button_text'))
              .backgroundColor($r('app.color.action_bg'))
              .borderRadius(20)
              .onClick(() => {
                this.refreshStatus();
                this.pageStack.pushPathByName('WalkingStarted', null);
              })
          }
          .align(Alignment.Center)

          ArcListItem() {
            Text($r('app.string.refresh_status'))
              .fontSize(10)
              .fontColor($r('app.color.link_text'))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .onClick(() => this.refreshStatus())
          }
          .align(Alignment.Center)
        }
        .space(LengthMetrics.px(8))
        .width('100%')
        .height('100%')
        .borderRadius('50%')
        .focusable(true)
        .focusOnTouch(true)
        .defaultFocus(true)
        .padding({ top: 30, bottom: 30 })
      }
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideBackButton(true)
    .ignoreLayoutSafeArea()
    .navDestination(this.PageMap)
    .backgroundColor($r('app.color.bg_primary'))
    .width('100%')
    .height('100%')
  }
}

@Component
struct WalkingStarted {
  @Consume('NavPathStack') pageStack: NavPathStack;
  status: AccessibilityStatus = createDefaultAccessibilityStatus();

  /**
   * Mirrors the start screen mode colors so the selected mode remains recognizable.
   */
  private modeColor(mode: StartMode): Resource {
    if (mode === 'doubleTouch') {
      return $r('app.color.mode_double_touch');
    }
    if (mode === 'accessible') {
      return $r('app.color.mode_accessible');
    }
    if (mode === 'fallback') {
      return $r('app.color.mode_fallback');
    }
    return $r('app.color.mode_standard');
  }

  /**
   * Maps the internal mode code to localized display text.
   */
  private modeText(mode: StartMode): Resource {
    if (mode === 'doubleTouch') {
      return $r('app.string.mode_double_touch');
    }
    if (mode === 'accessible') {
      return $r('app.string.mode_accessible');
    }
    if (mode === 'fallback') {
      return $r('app.string.mode_fallback');
    }
    return $r('app.string.mode_standard');
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        Circle()
          .width('94%')
          .height('94%')
          .fill($r('app.color.face_bg'))

        Column({ space: 7 }) {
          Text($r('app.string.walking_started'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .width('100%')

          Stack({ alignContent: Alignment.Center }) {
            Circle()
              .width(108)
              .height(108)
              .fill($r('app.color.progress_bg'))

            Circle()
              .width(84)
              .height(84)
              .fill($r('app.color.bg_primary'))

            Column({ space: 1 }) {
              Text($r('app.string.distance_120_m'))
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.route_primary'))

              Text($r('app.string.label_to_stop'))
                .fontSize(9)
                .fontColor($r('app.color.text_tertiary'))
            }
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .height(112)

          Column({ space: 4 }) {
            Text($r('app.string.destination_bus_stop_a'))
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .width('100%')

            Text(this.modeText(this.status.mode))
              .fontSize(9)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.modeColor(this.status.mode))
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor($r('app.color.chip_bg'))
              .borderRadius(8)
              .constraintSize({ maxWidth: '100%' })
          }
          .alignItems(HorizontalAlign.Center)
          .width('100%')

          Text($r('app.string.walking_short_instruction'))
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .width('100%')

          Button($r('app.string.stop'))
            .width('88%')
            .height(34)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.button_text'))
            .backgroundColor($r('app.color.stop_bg'))
            .borderRadius(17)
            .onClick(() => this.pageStack.pop())
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .width('68%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_primary'))
    }
    .hideTitleBar(true)
    .hideBackButton(true)
  }
}
