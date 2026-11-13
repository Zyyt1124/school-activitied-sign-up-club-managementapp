import { AppColors, AppText } from '../common/constants/AppTheme';

@Component
export struct EmptyState {
  @Prop title: string = '暂无内容';
  @Prop hint: string = '';

  build() {
    Column({ space: 8 }) {
      Text('○')
        .fontSize(40)
        .fontColor(AppColors.line)
      Text(this.title)
        .fontSize(AppText.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.inkSecondary)
      if (this.hint.length > 0) {
        Text(this.hint)
          .fontSize(AppText.caption)
          .fontColor(AppColors.muted)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 48, bottom: 48 })
    .justifyContent(FlexAlign.Center)
  }
}
