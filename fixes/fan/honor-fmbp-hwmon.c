// SPDX-License-Identifier: GPL-2.0
/*
 * hwmon driver for Honor MagicBook 14 Pro (FMB-P) EC fan tachometers.
 *
 * The EC exposes two little-endian RPM words in its RAM:
 *   0x2C/0x2D - fan 1, 0x2E/0x2F - fan 2
 * (discovered by diffing EC RAM dumps at idle vs. under CPU load).
 */

#include <linux/module.h>
#include <linux/hwmon.h>
#include <linux/acpi.h>
#include <linux/dmi.h>
#include <linux/platform_device.h>

#define FMBP_EC_FAN1_LO	0x2c
#define FMBP_EC_FAN1_HI	0x2d
#define FMBP_EC_FAN2_LO	0x2e
#define FMBP_EC_FAN2_HI	0x2f

static struct platform_device *fmbp_pdev;
static struct device *fmbp_hwmon_dev;

static int fmbp_read_fan(u8 lo_addr, u8 hi_addr, long *rpm)
{
	u8 lo, hi;
	int ret;

	ret = ec_read(lo_addr, &lo);
	if (ret)
		return ret;
	ret = ec_read(hi_addr, &hi);
	if (ret)
		return ret;

	*rpm = (hi << 8) | lo;
	return 0;
}

static int fmbp_hwmon_read(struct device *dev, enum hwmon_sensor_types type,
			   u32 attr, int channel, long *val)
{
	if (type != hwmon_fan || attr != hwmon_fan_input)
		return -EOPNOTSUPP;

	if (channel == 0)
		return fmbp_read_fan(FMBP_EC_FAN1_LO, FMBP_EC_FAN1_HI, val);
	if (channel == 1)
		return fmbp_read_fan(FMBP_EC_FAN2_LO, FMBP_EC_FAN2_HI, val);

	return -EOPNOTSUPP;
}

static const char * const fmbp_fan_labels[] = { "fan1", "fan2" };

static int fmbp_hwmon_read_string(struct device *dev,
				  enum hwmon_sensor_types type, u32 attr,
				  int channel, const char **str)
{
	if (type != hwmon_fan || attr != hwmon_fan_label ||
	    channel >= ARRAY_SIZE(fmbp_fan_labels))
		return -EOPNOTSUPP;

	*str = fmbp_fan_labels[channel];
	return 0;
}

static umode_t fmbp_hwmon_is_visible(const void *data,
				     enum hwmon_sensor_types type, u32 attr,
				     int channel)
{
	return 0444;
}

static const struct hwmon_channel_info * const fmbp_hwmon_info[] = {
	HWMON_CHANNEL_INFO(fan,
			   HWMON_F_INPUT | HWMON_F_LABEL,
			   HWMON_F_INPUT | HWMON_F_LABEL),
	NULL
};

static const struct hwmon_ops fmbp_hwmon_ops = {
	.is_visible = fmbp_hwmon_is_visible,
	.read = fmbp_hwmon_read,
	.read_string = fmbp_hwmon_read_string,
};

static const struct hwmon_chip_info fmbp_hwmon_chip_info = {
	.ops = &fmbp_hwmon_ops,
	.info = fmbp_hwmon_info,
};

static const struct dmi_system_id fmbp_dmi_table[] = {
	{
		.matches = {
			DMI_MATCH(DMI_SYS_VENDOR, "HONOR"),
			DMI_MATCH(DMI_PRODUCT_NAME, "FMB-P"),
		},
	},
	{}
};
MODULE_DEVICE_TABLE(dmi, fmbp_dmi_table);

static int __init fmbp_hwmon_init(void)
{
	if (!dmi_check_system(fmbp_dmi_table))
		return -ENODEV;

	fmbp_pdev = platform_device_register_simple("honor_fmbp_hwmon", -1,
						    NULL, 0);
	if (IS_ERR(fmbp_pdev))
		return PTR_ERR(fmbp_pdev);

	fmbp_hwmon_dev = hwmon_device_register_with_info(&fmbp_pdev->dev,
			"honor_fmbp", NULL, &fmbp_hwmon_chip_info, NULL);
	if (IS_ERR(fmbp_hwmon_dev)) {
		platform_device_unregister(fmbp_pdev);
		return PTR_ERR(fmbp_hwmon_dev);
	}

	return 0;
}

static void __exit fmbp_hwmon_exit(void)
{
	hwmon_device_unregister(fmbp_hwmon_dev);
	platform_device_unregister(fmbp_pdev);
}

module_init(fmbp_hwmon_init);
module_exit(fmbp_hwmon_exit);

MODULE_DESCRIPTION("Honor MagicBook 14 Pro (FMB-P) EC fan hwmon driver");
MODULE_LICENSE("GPL");
