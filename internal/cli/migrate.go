package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

var migrateCmd = &cobra.Command{
	Use:   "migrate [type] [source] [target]",
	Short: "Execute a migration",
	Args:  cobra.ExactArgs(3),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Migrating %s from %s to %s\n", args[0], args[1], args[2])
	},
}

func init() {
	rootCmd.AddCommand(migrateCmd)
}
