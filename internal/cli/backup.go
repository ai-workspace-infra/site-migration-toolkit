package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

var backupCmd = &cobra.Command{
	Use:   "backup",
	Short: "Manage backups",
}

var backupCreateCmd = &cobra.Command{
	Use:   "create [environment]",
	Short: "Create a backup",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Creating backup for environment: %s\n", args[0])
	},
}

func init() {
	backupCmd.AddCommand(backupCreateCmd)
	rootCmd.AddCommand(backupCmd)
}
