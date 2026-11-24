// SPDX-License-Identifier: GPL-2.0-only
// SPDX-FileCopyrightText: 2026 Philip Walsh (drphilth) — https://github.com/drphilth/honor-magicbook-pro-14-ubuntu
/*
 * honor-fmbp-kbdlight - keyboard backlight LED for the HONOR MagicBook Pro 14 (FMB-P).
 *
 * The in-tree huawei-wmi driver doesn't expose the keyboard backlight, and the
 * firmware's WMI kbd-light methods are no-ops on this model (verified: commands
 * return AE_OK but do nothing). The backlight is controllable via EC RAM field
 * KBBL at offset 0x41 (reverse-engineered from the DSDT):
 *   0x04 = off, 0x02 = low, 0x03 = high   (reactive: on with activity, times out)
 *   0x01 = latch the current level -> steady (no timeout)
 * We expose a standard "huawei::kbd_backlight" LED (so UPower/GNOME/KDE control
 * it natively) plus a "mode" attribute to pick reactive vs steady.
 *
 * Fn+Space is handled by the EC itself (it cycles KBBL off/low/high). To let the
 * desktop follow, KBBL is polled and hardware-initiated changes are reported via
 * brightness_hw_changed (LED_BRIGHT_HW_CHANGED). The inactivity timeout does not
 * change KBBL, and the latch value 0x01 is ignored (colorcube, issue #38).
 */
#include <linux/module.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/leds.h>
#include <linux/acpi.h>
#include <linux/dmi.h>
#include <linux/workqueue.h>

#define KBBL_OFFSET 0x41
#define KBBL_OFF    0x04
#define KBBL_LOW    0x02
#define KBBL_HIGH   0x03
#define KBBL_LATCH  0x01
#define LATCH_DELAY_MS 1500

static unsigned int poll_ms = 300;
module_param(poll_ms, uint, 0644);
MODULE_PARM_DESC(poll_ms, "KBBL poll interval in ms to report Fn+Space changes (0 = off)");

static bool steady;                       /* false = reactive (default) */
static enum led_brightness cur_bright = 1;/* logical level (KBBL hides it once latched) */
static struct delayed_work latch_work;
static struct delayed_work poll_work;
static DEFINE_MUTEX(kbd_lock);
static struct led_classdev kbd_led;

static u8 level_to_kbbl(enum led_brightness b)
{
	switch (b) {
	case 0:  return KBBL_OFF;
	case 1:  return KBBL_LOW;
	default: return KBBL_HIGH;
	}
}

static void latch_fn(struct work_struct *w)
{
	ec_write(KBBL_OFFSET, KBBL_LATCH);   /* freeze current level, disable timeout */
}

static int apply(enum led_brightness b)
{
	int ret;

	cancel_delayed_work_sync(&latch_work);
	ret = ec_write(KBBL_OFFSET, level_to_kbbl(b));
	if (!ret && steady && b > 0)
		schedule_delayed_work(&latch_work, msecs_to_jiffies(LATCH_DELAY_MS));
	return ret;
}

static int kbd_set(struct led_classdev *cdev, enum led_brightness b)
{
	int ret;

	mutex_lock(&kbd_lock);
	cur_bright = b;
	ret = apply(b);
	mutex_unlock(&kbd_lock);
	return ret;
}

/* map a raw KBBL value to a level; -1 for "unknown/latched, keep current" */
static int kbbl_to_level(u8 v)
{
	switch (v) {
	case KBBL_OFF:  return 0;
	case KBBL_LOW:  return 1;
	case KBBL_HIGH: return 2;
	default:        return -1;
	}
}

static void poll_fn(struct work_struct *w)
{
	u8 v;
	int lvl;

	if (!poll_ms)
		return;
	mutex_lock(&kbd_lock);
	if (!ec_read(KBBL_OFFSET, &v)) {
		lvl = kbbl_to_level(v);
		if (lvl >= 0 && lvl != cur_bright) {
			cur_bright = lvl;   /* changed by the EC (Fn+Space) */
			led_classdev_notify_brightness_hw_changed(&kbd_led, lvl);
		}
	}
	mutex_unlock(&kbd_lock);
	queue_delayed_work(system_freezable_wq, &poll_work, msecs_to_jiffies(poll_ms));
}

static enum led_brightness kbd_get(struct led_classdev *cdev)
{
	return cur_bright;   /* logical value; raw KBBL is unreliable once latched */
}

static ssize_t mode_show(struct device *dev, struct device_attribute *a, char *buf)
{
	return sysfs_emit(buf, "%s\n", steady ? "steady" : "reactive");
}

static ssize_t mode_store(struct device *dev, struct device_attribute *a,
			  const char *buf, size_t count)
{
	if (sysfs_streq(buf, "steady"))
		steady = true;
	else if (sysfs_streq(buf, "reactive"))
		steady = false;
	else
		return -EINVAL;
	mutex_lock(&kbd_lock);
	apply(cur_bright);          /* re-apply current level in the new mode */
	mutex_unlock(&kbd_lock);
	return count;
}
static DEVICE_ATTR_RW(mode);

static struct attribute *kbd_attrs[] = { &dev_attr_mode.attr, NULL };
ATTRIBUTE_GROUPS(kbd);

static struct led_classdev kbd_led = {
	.name			= "huawei::kbd_backlight",
	.max_brightness		= 2,
	.brightness		= 1,   /* default: low */
	.brightness_set_blocking = kbd_set,
	.brightness_get		= kbd_get,
	.groups			= kbd_groups,
	.flags			= LED_CORE_SUSPENDRESUME | LED_BRIGHT_HW_CHANGED,
};

static struct platform_device *pdev;

static const struct dmi_system_id honor_fmbp[] = {
	{ .matches = {
		DMI_MATCH(DMI_SYS_VENDOR, "HONOR"),
		DMI_MATCH(DMI_PRODUCT_NAME, "FMB-P"),
	} },
	{ }
};

static int __init kbdlight_init(void)
{
	int ret;

	if (!dmi_check_system(honor_fmbp)) {
		pr_info("honor-fmbp-kbdlight: not a HONOR FMB-P, skipping\n");
		return -ENODEV;
	}
	INIT_DELAYED_WORK(&latch_work, latch_fn);
	pdev = platform_device_register_simple("honor-fmbp-kbdlight", -1, NULL, 0);
	if (IS_ERR(pdev))
		return PTR_ERR(pdev);
	ret = led_classdev_register(&pdev->dev, &kbd_led);
	if (ret) {
		platform_device_unregister(pdev);
		return ret;
	}
	apply(cur_bright);   /* sync EC to the reported default so they can't disagree */
	INIT_DELAYED_WORK(&poll_work, poll_fn);
	if (poll_ms)
		queue_delayed_work(system_freezable_wq, &poll_work, msecs_to_jiffies(poll_ms));
	pr_info("honor-fmbp-kbdlight: registered %s (default: low, reactive)\n", kbd_led.name);
	return 0;
}

static void __exit kbdlight_exit(void)
{
	cancel_delayed_work_sync(&poll_work);
	cancel_delayed_work_sync(&latch_work);
	led_classdev_unregister(&kbd_led);
	platform_device_unregister(pdev);
}

module_init(kbdlight_init);
module_exit(kbdlight_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Keyboard backlight LED for HONOR MagicBook Pro 14 (FMB-P)");
MODULE_AUTHOR("MagicBook Linux project");
