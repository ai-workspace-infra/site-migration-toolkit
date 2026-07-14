package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

var rollbackCmd = &cobra.Command{
	Use:   "rollback [environment]",
	Short: "Rollback a deployment",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Rolling back environment: %s\n", args[0])
	},
}

func init() {
	rootCmd.AddCommand(rollbackCmd)
}
