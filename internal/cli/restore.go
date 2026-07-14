package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

var restoreCmd = &cobra.Command{
	Use:   "restore [environment] [backup-id]",
	Short: "Restore from a backup",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Restoring environment %s from backup %s\n", args[0], args[1])
	},
}

func init() {
	rootCmd.AddCommand(restoreCmd)
}
